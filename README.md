# StyleSense — Semantic Web Clothing Recommendation System

A Java EE / JSP web application that uses **Apache Jena** and **SPARQL** to query an OWL clothing ontology and surface personalised recommendations for Men, Women, and Kids customers.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Ontology Design](#ontology-design)
6. [Pages & Features](#pages--features)
7. [SPARQL Queries](#sparql-queries)
8. [Setup & Deployment](#setup--deployment)
9. [Extending the Project](#extending-the-project)

---

## Project Overview

StyleSense is a semantic-web-powered clothing store that reads a custom OWL ontology (`Clothing_Ontology.owl`) at runtime, runs SPARQL queries through Jena, and presents product recommendations grouped by customer segment (Men / Women / Kids).

Key goals:

- Demonstrate real-world use of OWL ontologies inside a Java web application.
- Show how the `hasRecommendation` object property links users to clothing items.
- Provide a built-in SPARQL playground for ad-hoc exploration of the ontology.

---

## Architecture

```
Browser
  │
  ▼
Apache Tomcat (Jakarta EE)
  ├── ClothingStore.jsp   ← Main recommendation page
  ├── CustomQuery.jsp     ← Ad-hoc SPARQL interface
  └── clothing_style.css  ← Shared stylesheet
        │
        ▼
  Apache Jena (OntModel / SPARQL)
        │
        ▼
  Clothing_Ontology.owl   (loaded from /ontology/ at request time)
```

The ontology is loaded fresh on each page request using `OntModelSpec.OWL_MEM` (in-memory, no reasoning). If you need inference (e.g. to resolve inverse properties automatically), swap `OWL_MEM` for `OWL_MEM_MICRO_RULE` or `OWL_MEM_RDFS_INF`.

---

## Technology Stack

| Layer | Technology |
|---|---|
| Web container | Apache Tomcat 10+ (Jakarta EE 9+) |
| Server-side logic | Java / JSP (scriptlets) |
| Semantic layer | Apache Jena 4.x |
| Query language | SPARQL 1.1 |
| Ontology format | OWL/RDF-XML |
| Fonts | Cormorant Garamond, DM Sans (Google Fonts) |
| Styling | Vanilla CSS (custom properties) |

---

## Project Structure

```
clothing_recommendation/
├── src/main/webapp/
│   ├── META-INF/
│   ├── WEB-INF/
│   │   ├── lib/                    ← Jena JARs go here
│   │   └── ontology/
│   │       ├── Clothing_Ontology.owl
│   └── images/
│       ├── men/
│       │   ├── Men_BlackLeatherJacket.jpeg
│       │   ├── Men_BlueJeans.jpeg
│       │   ├── Men_ClassicSuit.jpeg
│       │   ├── Men_SportyShorts.jpeg
│       │   └── Men_WhiteFormalShirt.jpeg
│       ├── women/
│       │   ├── Women_BeigeWinterCoat.jpeg
│       │   ├── Women_CasualBlouse.jpeg
│       │   ├── Women_ClassicSkirt.jpeg
│       │   ├── Women_RedDress.jpeg
│       │   └── Women_SportyLeggings.jpeg
│       └── kids/
│           ├── Kids_BlueTshirt.jpeg
│           ├── Kids_CasualSweater.jpeg
│           ├── Kids_RedWinterJacket.jpeg
│           ├── Kids_SportyPants.jpeg
│           └── Kids_WhiteSneakers.jpeg
│   ├── ClothingStore.jsp           ← Main page
│   ├── CustomQuery.jsp             ← SPARQL playground
│   └── clothing_style.css          ← Global styles
└── build/
```

> **Note:** Place the Jena fat-JAR (e.g. `apache-jena-libs-4.x.x.jar`) and its dependencies inside `WEB-INF/lib/`.

---

## Ontology Design

**Namespace:** `http://www.semanticweb.org/malakhussein/ontologies/2026/3/clothing-ontology#`

### Classes

| Class | Description |
|---|---|
| `ClothingItem` | Root class for all garments |
| `MenWear` | Subclass of ClothingItem — items for men |
| `WomenWear` | Subclass of ClothingItem — items for women |
| `KidsWear` | Subclass of ClothingItem — items for kids |
| `User` | A customer of the store |
| `Men` | Subclass of User — male customers |
| `Women` | Subclass of User — female customers |
| `Kids` | Subclass of User — child customers |
| `Brand` | A clothing brand (Nike, Zara, …) |
| `Color` | A colour (Black, Blue, Red, …) |
| `Style` | A style category (Casual, Formal, Sporty, …) |
| `Season` | A season (Spring, Summer, Autumn, Winter) |
| `Feature` | Superclass shared by Brand, Color, Style |

### Key Object Properties

| Property | Domain | Range | Description |
|---|---|---|---|
| `hasRecommendation` | User | ClothingItem | Links a user to their recommended items |
| `isRecommendedFor` | ClothingItem | User | Inverse of hasRecommendation |
| `hasBrand` | ClothingItem | Brand | Brand of a garment |
| `hasColor` | ClothingItem | Color | Colour of a garment |
| `hasStyle` | ClothingItem | Style | Style category |
| `isSuitableFor` | ClothingItem | Season | Seasonal suitability |
| `worksWellWith` | ClothingItem | ClothingItem | Outfit pairing (symmetric) |
| `isSimilarTo` | ClothingItem | ClothingItem | Similarity relation (symmetric) |
| `userLikesBrand` | User | Brand | User brand preference |
| `userLikesColor` | User | Color | User colour preference |
| `userLikesStyle` | User | Style | User style preference |
| `userPrefersSeason` | User | Season | User season preference |
| `hasPurchased` | User | ClothingItem | Purchase history |
| `hasLiked` | User | ClothingItem | Wishlist / likes |

### Data Properties

| Property | Domain | Range | Example |
|---|---|---|---|
| `hasName` | ClothingItem | xsd:string | "Navy Blue Suit" |
| `hasPrice` | ClothingItem | xsd:decimal | 3200.0 |
| `hasImagePath` | ClothingItem | xsd:string | "images/men/Men_ClassicSuit.jpeg" |

### Individuals (Users)

| Name | Class | Recommendations |
|---|---|---|
| User_Ahmed | Men | Leather Jacket, Classic Suit, Formal Shirt |
| User_Ali | Men | Leather Jacket, Classic Suit |
| User_Ziad | Men | Leather Jacket, Classic Suit |
| User_Mohamed | Men | Sporty Shorts |
| User_Omar | Men | Formal Shirt |
| User_Afnan | Women | Winter Coat, Classic Skirt |
| User_Aya | Women | Sporty Leggings |
| User_Heballah | Women | Casual Blouse |
| User_Malak | Women | Red Dress, Sporty Leggings |
| User_Mariem | Women | Classic Skirt |
| User_Adam | Kids | White Sneakers |
| User_Jana | Kids | Red Winter Jacket |
| User_Laila | Kids | Sporty Pants, White Sneakers |
| User_Selim | Kids | Sporty Pants |
| User_Yassin | Kids | Casual Sweater |

---

## Pages & Features

### ClothingStore.jsp — Main Page
<div class="page-visuals" style="margin: 20px 0; text-align: center;">
    <h3>Application Interface Preview</h3>
   <h4>Main page</h4> 
<img src="/src/main/webapp/images/screenshots/main_page_visual.png" 
     alt="StyleSense Main Page Preview" 
     style="max-width: 100%; height: auto; border: 1px solid #ccc; margin-bottom: 15px; border-radius: 4px;">
  <h4>Filtered main page</h4> 
<img src="/src/main/webapp/images/screenshots/main_page_visual_filter.png" 
     alt="UI Component Layout" 
     style="max-width: 100%; height: auto; border: 1px solid #ccc; border-radius: 4px;">
</div>

- **Tab navigation** — switches between Men / Women / Kids segments.
- **Sidebar filters** — Brand, Color, Style (links pass `?tab=` and filter parameters; extend the SPARQL query to apply them).
- **Active SPARQL display** — shows the running query in the sidebar.
- **Per-user sections** — each user gets an avatar card and a product grid with image, name, and price.
- **Image fallback** — if the JPEG is missing, a placeholder emoji is shown.

### CustomQuery.jsp — SPARQL Playground
<div class="playground-visual" style="margin: 20px 0; text-align: center;">
    <h3>SPARQL Playground Guide</h3>
   <h4>Custom query page</h4>
<img src="/src/main/webapp/images/screenshots/custom_query.png" 
     alt="SPARQL Playground Preview" 
     style="max-width: 100%; height: auto; border: 1px solid #ccc; border-radius: 4px;">
</div>

- **Variable input** — type `?var1 ?var2 …` to select any columns.
- **WHERE clause textarea** — write any SPARQL body; the page wraps it with prefixes and `SELECT`.
- **Preset examples** — five one-click queries covering the most common patterns.
- **Tabular results** — numbered rows with one column per variable.
- **Error display** — Jena parse/execution errors are shown inline.

---

## SPARQL Queries

All queries automatically receive these prefixes:

```sparql
PREFIX cl:   <http://www.semanticweb.org/malakhussein/ontologies/2026/3/clothing-ontology#>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd:  <http://www.w3.org/2001/XMLSchema#>
```

### Get all Men's recommendations

```sparql
SELECT ?user ?item ?name ?price WHERE {
  ?user rdf:type cl:Men .
  ?user cl:hasRecommendation ?item .
  ?item cl:hasName ?name .
  ?item cl:hasPrice ?price .
}
```

### Get recommendations for a specific user

```sparql
SELECT ?item ?name ?price WHERE {
  cl:User_Ahmed cl:hasRecommendation ?item .
  ?item cl:hasName ?name .
  ?item cl:hasPrice ?price .
}
```

### Find items suitable for Winter

```sparql
SELECT ?item ?name ?price WHERE {
  ?item cl:isSuitableFor cl:Season_Winter .
  ?item cl:hasName ?name .
  ?item cl:hasPrice ?price .
}
```

### Find items that work well together

```sparql
SELECT ?item1 ?name1 ?item2 ?name2 WHERE {
  ?item1 cl:worksWellWith ?item2 .
  ?item1 cl:hasName ?name1 .
  ?item2 cl:hasName ?name2 .
}
```

### Find all users who like a specific brand

```sparql
SELECT ?user WHERE {
  ?user cl:userLikesBrand cl:Brand_Nike .
}
```

---

## Setup & Deployment

### Prerequisites

- JDK 17+
- Apache Tomcat 10.1+
- Apache Jena 4.x (download from https://jena.apache.org/)
- Eclipse IDE for Enterprise Java (optional)

### Steps

1. **Clone / import** the project into Eclipse as a Dynamic Web Project.
2. **Add Jena JARs** — copy all JARs from the Jena `lib/` folder into `WEB-INF/lib/`.
3. **Place the ontology** — ensure `Clothing_Ontology.owl` is at `src/main/webapp/WEB-INF/ontology/Clothing_Ontology.owl`.
4. **Place images** — copy the `images/` folder into `src/main/webapp/WEB-INF/ontology/images/`.
5. **Deploy to Tomcat** — right-click the project → *Run As* → *Run on Server*.
6. **Open** `http://localhost:8080/clothing_recommendation/ClothingStore.jsp` in your browser.

### Required JARs (Jena 4.x)

```
jena-arq-*.jar
jena-core-*.jar
jena-iri-*.jar
jena-base-*.jar
slf4j-api-*.jar
slf4j-simple-*.jar   (or another SLF4J binding)
```

---

## Extending the Project

### Add sidebar filtering to SPARQL

In `ClothingStore.jsp`, extend the WHERE clause of `queryRecommendations()`:

```java
// Add inside the WHERE { } string:
if (filterBrand != null && !filterBrand.isEmpty()) {
    whereExtra += "?item cl:hasBrand cl:Brand_" + filterBrand + " . ";
}
```

### Enable OWL reasoning

Swap `OWL_MEM` for a reasoner-backed spec to let Jena infer inverse properties automatically:

```java
OntModel model = ModelFactory.createOntologyModel(OntModelSpec.OWL_MEM_MICRO_RULE);
```

### Add an item detail page

Create `ItemDetail.jsp` that reads `?id` from the query string and runs:

```sparql
SELECT ?name ?price ?img ?brand ?color ?style WHERE {
  cl:<id> cl:hasName ?name .
  cl:<id> cl:hasPrice ?price .
  OPTIONAL { cl:<id> cl:hasImagePath ?img }
  OPTIONAL { cl:<id> cl:hasBrand ?brand }
  OPTIONAL { cl:<id> cl:hasColor ?color }
  OPTIONAL { cl:<id> cl:hasStyle ?style }
}
```

### Add a shopping cart

Store selected item IDs in `HttpSession` and create a `Cart.jsp` that summarises them with totals.

---

*Built for the Semantic Web course — Faculty of Computers and Artificial Intelligence.*
