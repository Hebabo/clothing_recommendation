<%@ page import="
org.apache.jena.ontology.OntModel,
org.apache.jena.ontology.OntModelSpec,
org.apache.jena.query.*,
org.apache.jena.rdf.model.ModelFactory,
org.apache.jena.rdf.model.RDFNode,
jakarta.servlet.ServletContext,
java.util.*
" %>
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%!
    final String NS = "http://www.semanticweb.org/malakhussein/ontologies/2026/3/clothing-ontology#";


public List<Map<String,String>> runQuery(String queryStr, OntModel model) {
    List<Map<String,String>> rows = new ArrayList<>();
    try {
        Query query = QueryFactory.create(queryStr);
        try (QueryExecution qexec = QueryExecutionFactory.create(query, model)) {
            ResultSet rs = qexec.execSelect();
            while (rs.hasNext()) {
                QuerySolution soln = rs.nextSolution();
                Map<String,String> row = new HashMap<>();
                for (String var : rs.getResultVars()) {
                    RDFNode node = soln.get(var);
                    if (node != null) {
                        if (node.isLiteral()) row.put(var, node.asLiteral().getString());
                        else {
                            String uri = node.toString();
                            row.put(var, uri.contains("#") ? uri.substring(uri.indexOf("#")+1) : uri);
                        }
                    } else row.put(var, "");
                }
                rows.add(row);
            }
        }
    } catch (Exception e) {
        System.err.println("SPARQL execution error: " + e.getMessage());
        e.printStackTrace();
    }
    return rows;
}

    public List<String> getIndividualsOfType(String className, OntModel model) {
        List<String> individuals = new ArrayList<>();
        String queryStr = "PREFIX cl: <" + NS + "> " +
                          "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
                          "SELECT ?ind WHERE { ?ind rdf:type cl:" + className + " . } ORDER BY ?ind";
        List<Map<String,String>> rows = runQuery(queryStr, model);
        for (Map<String,String> row : rows) {
            String localName = row.get("ind");
            if (localName.startsWith(className + "_")) {
                localName = localName.substring(className.length() + 1);
            }
            individuals.add(localName);
        }
        Collections.sort(individuals);
        return individuals;
    }

    // Compact full URIs to prefixed form (cl:LocalName)
    String compactQuery(String query, String ns) {
        // Replace <fullURI> with cl:localname (after #)
        // Pattern: <ns + anything up to '>'
        String escapedNs = ns.replace("/", "\\/").replace("#", "\\#");
        String regex = "<(" + escapedNs + ")([^>]+)>";
        String replacement = "cl:$2";
        String compacted = query.replaceAll(regex, replacement);
        // Also ensure the PREFIX line remains
        if (!compacted.contains("PREFIX cl:")) {
            compacted = "PREFIX cl: <" + ns + ">\n" + compacted;
        }
        return compacted;
    }

    // Returns a map: preferences and also the queries used (only non-empty)
    public Map<String,Object> getUserPreferencesWithQueries(String userLocalName, OntModel model) {
        Map<String,Object> result = new HashMap<>();
        Map<String,List<String>> prefs = new LinkedHashMap<>();
        Map<String,String> queries = new LinkedHashMap<>();

        String fullUserURI = NS + userLocalName;
        // Properties to fetch: display name, property name
        String[][] props = {
            {"brand", "userLikesBrand"},
            {"color", "userLikesColor"},
            {"style", "userLikesStyle"},
            {"season", "userPrefersSeason"},
            {"purchased", "hasPurchased"},
            {"liked", "hasLiked"}
        };

        for (String[] prop : props) {
            String display = prop[0];
            String propName = prop[1];
            List<String> vals = new ArrayList<>();
            String q = "PREFIX cl: <" + NS + "> SELECT ?val WHERE { <" + fullUserURI + "> cl:" + propName + " ?val }";
            List<Map<String,String>> rows = runQuery(q, model);
            for (Map<String,String> row : rows) {
                String val = row.get("val");
                if (val != null && !val.isEmpty()) {
                    if (val.contains("_")) val = val.substring(val.indexOf("_")+1);
                    vals.add(val);
                }
            }
            // Only store if non-empty
            if (!vals.isEmpty()) {
                prefs.put(display, vals);
                queries.put(display, compactQuery(q, NS));
            }
        }

        result.put("prefs", prefs);
        result.put("queries", queries);
        return result;
    }
    
    String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }
%>
<%
	String reload = request.getParameter("reload");
	if ("true".equals(reload)) {
	    application.removeAttribute("ontModel");
	    System.out.println("Ontology model removed from cache. Will reload on next request.");
	}
    OntModel model = (OntModel) application.getAttribute("ontModel");
    if (model == null) {
        synchronized (application) {
            model = (OntModel) application.getAttribute("ontModel");
            if (model == null) {
                model = ModelFactory.createOntologyModel(OntModelSpec.OWL_MEM);
                String path = application.getRealPath("/ontology/Clothing_Ontology.owl");
                if (path == null) throw new RuntimeException("Ontology file not found");
                model.read(path);
                application.setAttribute("ontModel", model);
            }
        }
    }

    // Load dynamic filter options from ontology
    List<String> allBrands = getIndividualsOfType("Brand", model);
    List<String> allColors = getIndividualsOfType("Color", model);
    List<String> allStyles = getIndividualsOfType("Style", model);
    List<String> allSeasons = getIndividualsOfType("Season", model);

    String activeTab = request.getParameter("tab");
    if (activeTab == null) activeTab = "men";
    String filterBrand = request.getParameter("brand");
    String filterColor = request.getParameter("color");
    String filterStyle = request.getParameter("style");
    String filterSeason = request.getParameter("season");
    String searchText = request.getParameter("search");
    if (searchText == null) searchText = "";

    String userClass = "Men";
    if ("women".equals(activeTab)) userClass = "Women";
    else if ("kids".equals(activeTab)) userClass = "Kids";

    StringBuilder where = new StringBuilder();
    where.append("?user rdf:type cl:").append(userClass).append(" . \n");
    where.append("?user cl:hasRecommendation ?item . \n");
    where.append("?item cl:hasName ?name . \n");
    where.append("?item cl:hasPrice ?price . \n");
    where.append("OPTIONAL { ?item cl:hasImagePath ?img } \n");
    if (filterBrand != null && !filterBrand.isEmpty()) {
        where.append("?item cl:hasBrand cl:Brand_").append(filterBrand).append(" . \n");
    }
    if (filterColor != null && !filterColor.isEmpty()) {
        where.append("?item cl:hasColor cl:Color_").append(filterColor).append(" . \n");
    }
    if (filterStyle != null && !filterStyle.isEmpty()) {
        where.append("?item cl:hasStyle cl:Style_").append(filterStyle).append(" . \n");
    }
    if (filterSeason != null && !filterSeason.isEmpty()) {
        where.append("?item cl:isSuitableFor cl:Season_").append(filterSeason).append(" . \n");
    }
    if (searchText != null && !searchText.trim().isEmpty()) {
        where.append(" FILTER(CONTAINS(LCASE(?name), LCASE(\"").append(searchText.trim().replace("\"", "\\\"")).append("\"))) ");
    }

    String fullQuery = "PREFIX cl: <" + NS + "> \n" +
                      "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n" +
                      "SELECT DISTINCT ?user ?item ?name ?price ?img \nWHERE { " +
                      where.toString() + " } ORDER BY ?user ?name";
    List<Map<String,String>> results = runQuery(fullQuery, model);

    Map<String, List<Map<String,String>>> groups = new LinkedHashMap<>();
    for (Map<String,String> row : results) {
        String userId = row.get("user");
        groups.computeIfAbsent(userId, k -> new ArrayList<>()).add(row);
    }

    // Compact the main query for display
    String compactMainQuery = compactQuery(fullQuery, NS);
%>
<%
    System.out.println("=== DEBUG ClothingStore.jsp ===");
    System.out.println("Query: " + fullQuery);
    System.out.println("Results count: " + results.size());
    if (results.isEmpty()) {
        System.out.println("No results. Checking if model is loaded correctly...");
        System.out.println("Model contains any statements? " + model.size());
        // Optionally list all individuals of type cl:Women to verify data is there
        String testQuery = "PREFIX cl: <" + NS + "> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> SELECT ?user WHERE { ?user rdf:type cl:Women } LIMIT 5";
        List<Map<String,String>> testResult = runQuery(testQuery, model);
        System.out.println("Number of Women individuals: " + testResult.size());
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>StyleSense — Clothing Recommendations</title>
    <link rel="stylesheet" href="clothing_style.css">
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond&family=DM+Sans&display=swap" rel="stylesheet">
    <style>
        .query-card { background: var(--ivory-dark); border-radius: var(--radius-md); padding: 1rem; margin-bottom: 1.5rem; border-left: 4px solid var(--terra); }
        .sparql-query { font-family: var(--font-mono); font-size: 0.8rem; color: var(--charcoal); background: var(--white); padding: 0.8rem; border-radius: var(--radius-sm); white-space: pre-wrap; word-break: break-all; border: 1px solid var(--border); }
        .pref-queries { margin-top: 0.5rem; }
        .pref-queries details { margin-top: 0.3rem; }
        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; overflow: auto; background-color: rgba(0,0,0,0.5); }
        .modal-content { background-color: #fefefe; margin: 5% auto; padding: 20px; border-radius: 20px; width: 80%; max-width: 700px; }
        .close { color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer; }
        .close:hover { color: black; }
        .item-card .item-info { display: flex; flex-direction: column; }
    </style>
</head>
<body>
<header class="site-header"><div class="header-inner"><div class="logo"><span class="logo-icon">✦</span><span class="logo-text">StyleSense</span></div><nav class="tab-nav"><a href="?tab=men" class="tab-link <%= "men".equals(activeTab) ? "active" : "" %>">♂ Men</a><a href="?tab=women" class="tab-link <%= "women".equals(activeTab) ? "active" : "" %>">♀ Women</a><a href="?tab=kids" class="tab-link <%= "kids".equals(activeTab) ? "active" : "" %>">★ Kids</a></nav><a href="CustomQuery.jsp" class="header-query-btn">Custom Query ›</a></div></header>
<section class="hero"><div class="hero-text"><p class="hero-eyebrow">Ontology‑Powered</p><h1 class="hero-title"><%= activeTab.substring(0,1).toUpperCase()+activeTab.substring(1) %>'s Collection</h1></div></section>
<div class="page-body">
    <aside class="sidebar">
        <div class="sidebar-section">
            <h3 class="sidebar-title">Filter by</h3>
            <form method="get" action="ClothingStore.jsp" id="filterForm">
                <input type="hidden" name="tab" value="<%= activeTab %>">
                <div class="filter-group"><label>Search item:</label><input type="text" name="search" class="form-input" value="<%= searchText %>" placeholder="e.g. jacket, shirt..."></div>
                <div class="filter-group"><label>Brand:</label><select name="brand" class="form-input" onchange="this.form.submit()"><option value="">All</option><% for (String b : allBrands) { %><option value="<%=b%>" <%= b.equals(filterBrand) ? "selected" : "" %>><%=b%></option><% } %></select></div>
                <div class="filter-group"><label>Color:</label><select name="color" class="form-input" onchange="this.form.submit()"><option value="">All</option><% for (String c : allColors) { %><option value="<%=c%>" <%= c.equals(filterColor) ? "selected" : "" %>><%=c%></option><% } %></select></div>
                <div class="filter-group"><label>Style:</label><select name="style" class="form-input" onchange="this.form.submit()"><option value="">All</option><% for (String s : allStyles) { %><option value="<%=s%>" <%= s.equals(filterStyle) ? "selected" : "" %>><%=s%></option><% } %></select></div>
                <div class="filter-group"><label>Season:</label><select name="season" class="form-input" onchange="this.form.submit()"><option value="">All</option><% for (String sn : allSeasons) { %><option value="<%=sn%>" <%= sn.equals(filterSeason) ? "selected" : "" %>><%=sn%></option><% } %></select></div>
                <button type="submit" class="clear-filter" style="margin-top:12px;">Apply Filters</button>
                <% if (filterBrand!=null || filterColor!=null || filterStyle!=null || filterSeason!=null || (searchText!=null && !searchText.isEmpty())) { %>
                    <a href="ClothingStore.jsp?tab=<%= activeTab %>" class="clear-filter">✕ Clear all</a>
                <% } %>
            </form>
        </div>
    </aside>
    <main class="main-content">
        <div class="query-card">
            <h3 style="margin-bottom:0.5rem;">Namespace & SPARQL Query used for this view</h3>
            <pre class="sparql-query" id="mainQuery"><%= escapeHtml(compactMainQuery) %></pre>
        </div>

        <% if (groups.isEmpty()) { %>
            <div class="empty-state">No recommendations found.</div>
        <% } else {
            for (Map.Entry<String, List<Map<String,String>>> entry : groups.entrySet()) {
                String userLocalName = entry.getKey();
                String userName = userLocalName.contains("_") ? userLocalName.substring(userLocalName.indexOf("_")+1) : userLocalName;
                List<Map<String,String>> items = entry.getValue();
                Map<String,Object> prefData = getUserPreferencesWithQueries(userLocalName, model);
                Map<String,List<String>> prefs = (Map<String,List<String>>) prefData.get("prefs");
                Map<String,String> prefQueries = (Map<String,String>) prefData.get("queries");
        %>
        <section class="user-section">
            <div class="user-header" style="align-items: flex-start;">
                <div class="user-avatar"><%= userName.charAt(0) %></div>
                <div>
                    <h2 class="user-name"><%= userName %></h2>
                    <p class="user-sub">
                        <% 
                            StringBuilder reason = new StringBuilder();
                            if (prefs.containsKey("brand")) reason.append("Likes Brand: ").append(String.join(", ", prefs.get("brand"))).append("  ");
                            if (prefs.containsKey("color")) reason.append("Likes Color: ").append(String.join(", ", prefs.get("color"))).append("  ");
                            if (prefs.containsKey("style")) reason.append("Likes Style: ").append(String.join(", ", prefs.get("style"))).append("  ");
                            if (prefs.containsKey("season")) reason.append("Prefers Season: ").append(String.join(", ", prefs.get("season"))).append("  ");
                            if (prefs.containsKey("purchased")) reason.append("Purchased: ").append(String.join(", ", prefs.get("purchased"))).append("  ");
                            if (prefs.containsKey("liked")) reason.append("Liked Items: ").append(String.join(", ", prefs.get("liked")));
                            if (reason.length() == 0) out.print("Based on personal preference");
                            else out.print(reason.toString());
                        %>
                    </p>
                    <!-- Only show queries that actually returned data -->
                    <% if (!prefQueries.isEmpty()) { %>
                        <div class="pref-queries">
                            <details>
                                <summary>View SPARQL queries for this user's preferences</summary>
                                <ul style="margin-top:0.5rem; list-style:none; padding-left:0;">
                                    <% for (Map.Entry<String,String> qEntry : prefQueries.entrySet()) { 
                                        String displayName = qEntry.getKey();
                                        String queryText = qEntry.getValue();
                                    %>
                                    <li><strong><%= displayName.substring(0,1).toUpperCase() + displayName.substring(1) %>:</strong> 
                                        <pre class="sparql-query" style="margin:0.2rem 0;" id="prefQuery_<%= userLocalName %>_<%= displayName %>"><%= escapeHtml(queryText) %></pre>
                                    </li>
                                    <% } %>
                                </ul>
                            </details>
                        </div>
                    <% } %>
                </div>
            </div>
            <div class="item-grid">
                <% for (Map<String,String> item : items) { 
                    String itemId = item.get("item");
                    String name = item.get("name");
                    String price = item.get("price");
                    String img = item.get("img");
                    if(img==null||img.isEmpty()) img = "";
                    if (img.startsWith("/images")) img = img.substring(1);
                %>
                <div class="item-card">
                    <a href="ItemDetail.jsp?id=<%= itemId %>&from=<%= activeTab %>">
                        <div class="item-img-wrap">
                            <% if(!img.isEmpty()) { %>
                                <img src="<%= img %>" alt="<%= name %>" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">
                                <div class="item-img-placeholder" style="display:none">👔</div>
                            <% } else { %>
                                <div class="item-img-placeholder">👔</div>
                            <% } %>
                        </div>
                        <div class="item-info"><p class="item-name"><%= name %></p><p class="item-price"><%= price %> EGP</p></div>
                    </a>
                </div>
                <% } %>
            </div>
        </section>
        <% } } %>
    </main>
</div>
<div id="quickViewModal" class="modal"><div class="modal-content"><span class="close">&times;</span><div id="modalContent">Loading...</div></div></div>
<footer class="site-footer"><p>StyleSense — Semantic Web Clothing Recommendation</p><a href="CustomQuery.jsp">Run custom SPARQL query →</a></footer>
</body>
</html>