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
    String localName(String uri) {
        return uri.contains("#") ? uri.substring(uri.indexOf("#")+1) : uri;
    }
    String addPrefixes(String query) {
        String prefixes = "PREFIX cl: <" + NS + ">\n" +
                          "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n" +
                          "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n" +
                          "PREFIX owl: <http://www.w3.org/2002/07/owl#>\n";
        if (!query.contains("PREFIX cl:")) query = prefixes + query;
        return query;
    }
    // Compact full URIs to prefixed form (cl:LocalName) but keep prefix IRIs intact
    String compactQuery(String query, String ns) {
        if (query == null) return "";
        String escapedNs = ns.replace("/", "\\/").replace("#", "\\#");
        String regex = "<(" + escapedNs + ")([^>]+)>";
        String replacement = "cl:$2";
        String compacted = query.replaceAll(regex, replacement);
        return compacted;
    }
    String escapeHtml(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }
%>
<%
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

    // Load stored queries
    List<Map<String,String>> storedQueries = new ArrayList<>();
    String sqQuery = "PREFIX cl: <" + NS + "> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
                     "SELECT ?q ?text WHERE { ?q rdf:type cl:StoredQuery . ?q cl:hasSPARQLText ?text }";
    try (QueryExecution qe = QueryExecutionFactory.create(sqQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) {
            QuerySolution sol = rs.nextSolution();
            String rawText = sol.getLiteral("text").getString();
            String adapted = rawText.replace("clothing-ontology:", "cl:");
            if (!adapted.contains("PREFIX owl:")) adapted = "PREFIX owl: <http://www.w3.org/2002/07/owl#>\n" + adapted;
            Map<String,String> row = new HashMap<>();
            row.put("name", localName(sol.get("q").toString()));
            row.put("full", adapted);
            storedQueries.add(row);
        }
    }

    // Fetch Classes, Object Properties, Data Properties
    String basePrefix = "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX owl: <http://www.w3.org/2002/07/owl#> ";
    String classQuery   = basePrefix + "SELECT DISTINCT ?c WHERE { ?c rdf:type owl:Class . FILTER(CONTAINS(STR(?c), \"#\")) } LIMIT 30";
    String objPropQuery = basePrefix + "SELECT DISTINCT ?p WHERE { ?p rdf:type owl:ObjectProperty . FILTER(CONTAINS(STR(?p), \"#\")) } LIMIT 30";
    String dataPropQuery= basePrefix + "SELECT DISTINCT ?p WHERE { ?p rdf:type owl:DatatypeProperty . FILTER(CONTAINS(STR(?p), \"#\")) } LIMIT 30";
    
    String individualsWithTypesQuery = "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
                                       "PREFIX owl: <http://www.w3.org/2002/07/owl#> " +
                                       "SELECT ?i ?class WHERE { " +
                                       "  ?i rdf:type ?class . " +
                                       "  FILTER(CONTAINS(STR(?i), \"#\")) " +
                                       "  FILTER(?class != owl:NamedIndividual) " +
                                       "} LIMIT 200";

    List<String> classes = new ArrayList<>();
    List<String> objProps = new ArrayList<>();
    List<String> dataProps = new ArrayList<>();
    Map<String, List<String>> individualsByClass = new TreeMap<>();

    try (QueryExecution qe = QueryExecutionFactory.create(classQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) classes.add(localName(rs.next().get("c").toString()));
        Collections.sort(classes);
    } catch (Exception e) {}
    try (QueryExecution qe = QueryExecutionFactory.create(objPropQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) objProps.add(localName(rs.next().get("p").toString()));
        Collections.sort(objProps);
    } catch (Exception e) {}
    try (QueryExecution qe = QueryExecutionFactory.create(dataPropQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) dataProps.add(localName(rs.next().get("p").toString()));
        Collections.sort(dataProps);
    } catch (Exception e) {}

    try (QueryExecution qe = QueryExecutionFactory.create(individualsWithTypesQuery, model)) {
        ResultSet rs = qe.execSelect();
        while (rs.hasNext()) {
            QuerySolution sol = rs.nextSolution();
            String individualLocal = localName(sol.get("i").toString());
            String classLocal = localName(sol.get("class").toString());
            classLocal = classLocal.replace("Brand_", "").replace("Color_", "").replace("Style_", "").replace("Season_", "");
            individualsByClass.computeIfAbsent(classLocal, k -> new ArrayList<>()).add(individualLocal);
        }
    } catch (Exception e) {}
    for (List<String> list : individualsByClass.values()) {
        Collections.sort(list);
    }

    // Handle POST
    List<Map<String,String>> results = null;
    String executedQuery = null;
    List<String> resultVars = null;
    String lastSelect = "", lastWhere = "";
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        lastSelect = request.getParameter("selectVars");
        lastWhere = request.getParameter("whereClause");
        if (lastSelect != null && lastWhere != null && !lastSelect.trim().isEmpty() && !lastWhere.trim().isEmpty()) {
            String fullQuery = "SELECT " + lastSelect + " WHERE { " + lastWhere + " }";
            fullQuery = addPrefixes(fullQuery);
            executedQuery = fullQuery;
            results = new ArrayList<>();
            try (QueryExecution qe = QueryExecutionFactory.create(fullQuery, model)) {
                ResultSet rs = qe.execSelect();
                resultVars = rs.getResultVars();
                while (rs.hasNext()) {
                    QuerySolution sol = rs.nextSolution();
                    Map<String,String> row = new LinkedHashMap<>();
                    for (String var : resultVars) {
                        RDFNode node = sol.get(var);
                        if (node == null) row.put(var, "");
                        else if (node.isLiteral()) row.put(var, node.asLiteral().getString());
                        else row.put(var, localName(node.toString()));
                    }
                    results.add(row);
                }
            } catch (Exception e) {
                results = null;
                request.setAttribute("error", e.getMessage());
            }
        }
    } else {
        lastSelect = "?item ?name ?price";
        lastWhere = "?item rdf:type cl:MenWear . ?item cl:hasName ?name . ?item cl:hasPrice ?price .";
    }
%>
<%
    System.out.println("=== DEBUG: Loading stored queries ===");
    for (Map<String,String> sq : storedQueries) {
        System.out.println("Found: " + sq.get("name"));
    }
    System.out.println("Total: " + storedQueries.size());
%>
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>StyleSense — Custom SPARQL Query</title><link rel="stylesheet" href="clothing_style.css"></head>
<style>
    .full-query-preview {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.75rem;
        background: #f5f0e8;
        padding: 0.8rem;
        border-radius: 8px;
        border-left: 3px solid #b86b4a;
        white-space: pre-wrap;
        word-break: break-all;
        margin: 0.5rem 0;
        overflow-x: auto;
    }

</style>
<body>
<header class="site-header"><div class="header-inner" style="justify-content: space-between;"><div class="logo"><span class="logo-icon">✦</span><span class="logo-text">StyleSense</span></div><nav><a href="ClothingStore.jsp" class="header-query-btn">Home</a></nav></div></header>
<section class="hero hero-query"><div class="hero-text"><h1 class="hero-title">Custom SPARQL Query</h1><p>Select a predefined query or build your own</p></div></section>
<div class="query-page-body">
    <div class="query-form-panel">
        <div class="ns-banner">
            <strong>Prefixes added automatically:</strong> cl:, rdf:, rdfs:, owl:
        </div>
        <div class="presets">
            <p class="preset-label">Pre‑defined Stored Queries</p>
            <select id="storedQuerySelect" class="form-input" style="margin-bottom:1rem;">
                <option value="">-- Select a query --</option>
                <% for (Map<String,String> sq : storedQueries) { 
                    String escaped = sq.get("full").replace("\\", "\\\\").replace("\"", "&quot;");
                %>
                    <option value="<%= escaped %>"><%= sq.get("name") %></option>
                <% } %>
            </select>
        </div>
        <form method="post" action="CustomQuery.jsp" class="sparql-form" id="queryForm">
            <label class="form-label">SELECT variables (e.g. ?item ?name)</label>
            <input type="text" name="selectVars" id="selectVars" class="form-input mono" value="<%= lastSelect %>">
            
            <label class="form-label" style="margin-top:1rem;">WHERE clause body</label>
            <textarea name="whereClause" id="whereClause" class="form-textarea mono" rows="8"><%= lastWhere %></textarea>
            
            <div style="margin: 0.5rem 0;">
                <select id="termInsert" class="form-input" style="width:auto; display:inline-block;">
                    <option value="">Insert term...</option>
                    <optgroup label="Classes">
                        <% for (String c : classes) { if(c.startsWith("_")) continue; %>
                        <option value="cl:<%= c %>"><%= c %></option>
                        <% } %>
                    </optgroup>
                    <optgroup label="Object Properties">
                        <% for (String p : objProps) { %>
                        <option value="cl:<%= p %>"><%= p %></option>
                        <% } %>
                    </optgroup>
                    <optgroup label="Data Properties">
                        <% for (String p : dataProps) { %>
                        <option value="cl:<%= p %>"><%= p %></option>
                        <% } %>
                    </optgroup>
                    <% for (Map.Entry<String, List<String>> entry : individualsByClass.entrySet()) { 
                        String className = entry.getKey();
                        List<String> indivs = entry.getValue();
                        if (indivs.isEmpty()) continue;
                    %>
                    <optgroup label="Individuals – <%= className %>">
                        <% for (String indiv : indivs) { %>
                        <option value="cl:<%= indiv %>"><%= indiv %></option>
                        <% } %>
                    </optgroup>
                    <% } %>
                </select>
                <button type="button" id="insertBtn" class="clear-filter" style="margin-left:5px;">Insert</button>
            </div>
            
            <button type="submit" class="run-btn">▶ Run Query</button>
            <button type="button" id="resetDefaultBtn" class="clear-filter" style="margin-top:0.5rem;">↺ Reset to default</button>
        </form>
    </div>
    <div class="query-results-panel">
        <% if (executedQuery != null && results != null) { 
            String compactedQuery = compactQuery(executedQuery, NS);
            String escapedQuery = escapeHtml(compactedQuery);
        %>
            <div class="results-header">
                <h2 class="results-title">Results (<%= results.size() %> rows)</h2>
                <pre class="full-query-preview" id="executedQueryPre"><%= escapedQuery %></pre>
            </div>
            <% if (results.isEmpty()) { %>
                <div class="no-results">No results.</div>
            <% } else { %>
                <div class="table-scroll">
                    <table class="results-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <% for (String v : resultVars) { %>
                                    <th><%= v %></th>
                                <% } %>
                            </tr>
                        </thead>
                        <tbody>
                            <% int rowNum = 1; for (Map<String,String> row : results) { %>
                                <tr>
                                    <td class="row-num"><%= rowNum++ %></td>
                                    <% for (String v : resultVars) { %>
                                        <td><%= row.get(v) != null ? row.get(v) : "" %></td>
                                    <% } %>
                                </tr>
                            <% } %>
                        </tbody>
                    </table>
                </div>
            <% } %>
        <% } else if (executedQuery != null && request.getAttribute("error") != null) { %>
            <div class="query-error"><strong>Error:</strong> <%= request.getAttribute("error") %></div>
        <% } else { %>
            <div class="results-placeholder"><div class="placeholder-icon">⬡</div><p>Select a query or write your own, then click Run</p></div>
        <% } %>
    </div>
</div>
<script>
function parseFullQuery(fullQuery) {
    let lines = fullQuery.split(/\r?\n/);
    let bodyLines = [];
    for (let line of lines) {
        let trimmed = line.trim();
        if (!trimmed.toUpperCase().startsWith("PREFIX")) {
            bodyLines.push(line);
        }
    }
    let queryStr = bodyLines.join("\n");
    let selectMatch = queryStr.match(/SELECT\s+(DISTINCT\s+)?([\s\S]+?)\s+WHERE\s*\{/i);
    if (!selectMatch) return null;
    let selectPart = (selectMatch[2] || "").trim();
    let whereStart = queryStr.indexOf("{", selectMatch.index + selectMatch[0].length - 1);
    if (whereStart === -1) return null;
    let braceCount = 1;
    let pos = whereStart + 1;
    while (braceCount > 0 && pos < queryStr.length) {
        if (queryStr[pos] === '{') braceCount++;
        else if (queryStr[pos] === '}') braceCount--;
        pos++;
    }
    let whereClause = queryStr.substring(whereStart + 1, pos - 1).trim();
    return { select: selectPart, where: whereClause };
}

function copyToClipboard(elementId) {
    let text = document.getElementById(elementId).innerText;
    navigator.clipboard.writeText(text).then(() => alert("Query copied!")).catch(err => console.error(err));
}

document.getElementById('storedQuerySelect').addEventListener('change', function() {
    let full = this.value;
    if (full) {
        let parts = parseFullQuery(full);
        if (parts) {
            document.getElementById('selectVars').value = parts.select;
            document.getElementById('whereClause').value = parts.where;
        } else {
            alert("Could not parse stored query. Please fill manually.");
        }
    }
});

document.getElementById('resetDefaultBtn').addEventListener('click', function() {
    document.getElementById('selectVars').value = "?item ?name ?price";
    document.getElementById('whereClause').value = "?item rdf:type cl:MenWear . ?item cl:hasName ?name . ?item cl:hasPrice ?price .";
    document.getElementById('storedQuerySelect').value = "";
});

let insertBtn = document.getElementById('insertBtn');
let termSelect = document.getElementById('termInsert');
insertBtn.addEventListener('click', function() {
    let term = termSelect.value;
    if (!term) return;
    let activeField = document.activeElement;
    if (activeField && (activeField.id === 'selectVars' || activeField.id === 'whereClause')) {
        let start = activeField.selectionStart;
        let end = activeField.selectionEnd;
        let text = activeField.value;
        let newText = text.substring(0, start) + term + text.substring(end);
        activeField.value = newText;
        activeField.selectionStart = activeField.selectionEnd = start + term.length;
        activeField.focus();
    } else {
        let where = document.getElementById('whereClause');
        let start = where.selectionStart;
        let end = where.selectionEnd;
        let text = where.value;
        let newText = text.substring(0, start) + term + text.substring(end);
        where.value = newText;
        where.selectionStart = where.selectionEnd = start + term.length;
        where.focus();
    }
    termSelect.value = "";
});
</script>
<footer class="site-footer"><a href="ClothingStore.jsp">← Back to main page</a></footer>
</body>
</html>