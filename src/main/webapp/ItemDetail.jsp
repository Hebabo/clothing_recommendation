<%@ page import="
org.apache.jena.ontology.OntModel,
org.apache.jena.ontology.OntModelSpec,
org.apache.jena.query.*,
org.apache.jena.rdf.model.ModelFactory,
org.apache.jena.rdf.model.RDFNode,
java.util.*
" %>
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%!
    final String NS = "http://www.semanticweb.org/malakhussein/ontologies/2026/3/clothing-ontology#";

    String localName(RDFNode node) {
        if (node == null) return "—";
        String uri = node.toString();
        return uri.contains("#") ? uri.substring(uri.indexOf("#")+1) : uri;
    }
    
    String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }

    // Compact full URIs to prefixed form (cl:LocalName)
    String compactQuery(String query, String ns) {
        String escapedNs = ns.replace("/", "\\/").replace("#", "\\#");
        String regex = "<(" + escapedNs + ")([^>]+)>";
        String replacement = "cl:$2";
        String compacted = query.replaceAll(regex, replacement);
        if (!compacted.contains("PREFIX cl:")) {
            compacted = "PREFIX cl: <" + ns + ">\n" + compacted;
        }
        return compacted;
    }
%>
<%
    OntModel model = (OntModel) application.getAttribute("ontModel");
    if (model == null) {
        synchronized (application) {
            model = (OntModel) application.getAttribute("ontModel");
            if (model == null) {
                model = ModelFactory.createOntologyModel(OntModelSpec.OWL_MEM);
                String path = application.getRealPath("/WEB-INF/ontology/Clothing_Ontology.owl");
                if (path == null || !new java.io.File(path).exists()) {
                    path = application.getRealPath("/ontology/Clothing_Ontology.owl");
                }
                model.read(path);
                application.setAttribute("ontModel", model);
            }
        }
    }

    String itemId = request.getParameter("id");
    String itemUri = (itemId == null || itemId.isEmpty()) ? "" : (itemId.startsWith(NS) ? itemId : NS + itemId);
    if (itemUri.isEmpty()) {
        response.sendError(400, "Missing item ID");
        return;
    }

    // Query details
    String queryStr = "PREFIX cl: <" + NS + ">\n" +
                      "SELECT ?name ?price ?img ?brand ?color ?style ?season\n" +
                      "WHERE {\n" +
                      "  <" + itemUri + "> cl:hasName ?name ;\n" +
                      "                    cl:hasPrice ?price .\n" +
                      "  OPTIONAL { <" + itemUri + "> cl:hasImagePath ?img }\n" +
                      "  OPTIONAL { <" + itemUri + "> cl:hasBrand ?brand }\n" +
                      "  OPTIONAL { <" + itemUri + "> cl:hasColor ?color }\n" +
                      "  OPTIONAL { <" + itemUri + "> cl:hasStyle ?style }\n" +
                      "  OPTIONAL { <" + itemUri + "> cl:isSuitableFor ?season }\n" +
                      "}";
    Query q = QueryFactory.create(queryStr);
    Map<String,String> details = new HashMap<>();
    try (QueryExecution qe = QueryExecutionFactory.create(q, model)) {
        ResultSet rs = qe.execSelect();
        if (rs.hasNext()) {
            QuerySolution sol = rs.nextSolution();
            details.put("name", sol.getLiteral("name") != null ? sol.getLiteral("name").getString() : "?");
            details.put("price", sol.getLiteral("price") != null ? sol.getLiteral("price").getString() : "?");
            details.put("img", sol.getLiteral("img") != null ? sol.getLiteral("img").getString() : "");
            details.put("brand", localName(sol.get("brand")));
            details.put("color", localName(sol.get("color")));
            details.put("style", localName(sol.get("style")));
            details.put("season", localName(sol.get("season")));
        }
    }

    // Works well with
    List<String> worksWith = new ArrayList<>();
    String wwQuery = "PREFIX cl: <" + NS + ">\n" +
                     "SELECT ?partner\n" +
                     "WHERE {\n" +
                     "  <" + itemUri + "> cl:worksWellWith ?partner\n" +
                     "}";
    try (QueryExecution qe = QueryExecutionFactory.create(wwQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) worksWith.add(localName(rs.next().get("partner")));
    }

    // Users for whom this item is recommended
    List<String> recommendedFor = new ArrayList<>();
    String recQuery = "PREFIX cl: <" + NS + ">\n" +
                      "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n" +
                      "SELECT ?user\n" +
                      "WHERE {\n" +
                      "  ?user cl:hasRecommendation <" + itemUri + ">\n" +
                      "}";
    try (QueryExecution qe = QueryExecutionFactory.create(recQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) {
            String user = localName(rs.next().get("user"));
            if (user.startsWith("User_")) user = user.substring(5);
            recommendedFor.add(user);
        }
    }

    // Compact queries for display
    String compactDetails = compactQuery(queryStr, NS);
    String compactWw = compactQuery(wwQuery, NS);
    String compactRec = compactQuery(recQuery, NS);
%>
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>StyleSense — Item Details</title><link rel="stylesheet" href="clothing_style.css"></head>
<style>
    .sparql-query { font-family: 'JetBrains Mono', monospace; font-size: 0.75rem; background: #f5f0e8; padding: 0.8rem; border-radius: 8px; border-left: 3px solid #b86b4a; white-space: pre-wrap; word-break: break-all; margin: 0.5rem 0; overflow-x: auto; }
    details { margin-top: 1.5rem; background: #fefefe; border-radius: 12px; padding: 0.5rem 1rem; }
    summary { font-weight: 600; cursor: pointer; color: var(--terra); }
    .namespace-badge { background: var(--ivory-dark); padding: 0.5rem; border-radius: var(--radius-sm); margin-bottom: 1rem; font-size: 0.8rem; }
    button.copy-btn { background: var(--terra-pale); border: none; border-radius: 4px; padding: 2px 8px; font-size: 0.7rem; cursor: pointer; margin-left: 10px; }
</style>
<body>
<header class="site-header"><div class="header-inner"><div class="logo"><span class="logo-icon">✦</span><span class="logo-text">StyleSense</span></div></div></header>
<div style="width:800px; margin:40px auto; background:#fff; padding:30px; border-radius:20px;">
    <a href="ClothingStore.jsp?tab=<%= request.getParameter("from")!=null?request.getParameter("from"):"men" %>" style="color:#b86b4a;">← Back</a>
    <div style="display:flex; gap:30px; margin-top:20px; flex-wrap:wrap; white-space: pre-line;">
        <div style="flex:1;">
            <% 
                String img = details.get("img");
                if (img != null && !img.isEmpty()) {
                    if (img.startsWith("/images")) img = img.substring(1);
            %>
                <img src="<%= img %>" style="width:100%; border-radius:12px;" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'">
                <div style="display:none; background:#eee; height:300px; align-items:center; justify-content:center;">No image</div>
            <% } else { %>
                <div style="background:#eee; height:300px; display:flex; align-items:center; justify-content:center;">No image available</div>
            <% } %>
        </div>
        <div style="flex:1;">
            <h1 style="font-family: 'Cormorant Garamond';"><%= details.get("name") %></h1>
            <p><strong>Brand:</strong> <%= details.get("brand").replace("Brand_","") %></p>
            <p><strong>Color:</strong> <%= details.get("color").replace("Color_","") %></p>
            <p><strong>Style:</strong> <%= details.get("style").replace("Style_","") %></p>
            <p><strong>Best for:</strong> <%= details.get("season").replace("Season_","") %></p>
            <% if(!worksWith.isEmpty()) { %>
                <p><strong>Works well with:</strong> <%= String.join(", ", worksWith) %></p>
            <% } %>
            <p><strong>Price:</strong><span style="background: #fede93; padding: 4px 12px; border-radius: 20px; font-size: large; font-weight: 700; margin-left: 10px;"> <%= details.get("price") %> EGP</span></p>
        </div>
    </div>
    <% if (!recommendedFor.isEmpty()) { %>
        <div style="display: flex; justify-content: space-around; align-items:center; border-top:1px solid #eee; padding-top:10px">
            <h3>Recommended for:</h3>
            <ul style="display:flex; flex-wrap:wrap; gap:10px; list-style:none; padding:0;">
                <% for (String user : recommendedFor) { %>
                    <li style="padding:12px 24px;"><div class="user-avatar"><%= user.charAt(0) %></div> <%= user %></li>
                <% } %>
            </ul>
        </div>
    <% } %>

    <details>
        <summary>View SPARQL queries used</summary>
        <h4>Item details query</h4>
        <pre class="sparql-query" id="detailsQuery"><%= escapeHtml(compactDetails) %></pre>
        <h4>Works well with query</h4>
        <pre class="sparql-query" id="wwQuery"><%= escapeHtml(compactWw) %></pre>
        <h4>Recommended for query</h4>
        <pre class="sparql-query" id="recQuery"><%= escapeHtml(compactRec) %></pre>
    </details>
</div>
</body>
