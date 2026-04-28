# QU Bus Route to Location Mapping

## Overview
This document shows which bus routes serve which locations on Qatar University campus.

---

## **Route Mapping by Location**

### **Metro Station** (Main Hub)
- **Routes:** Black Line, Brown Line, Maroon Line
- **Stop ID:** `metro`

### **Female Classrooms Building (GCR)** (D06 - Main Hub)
- **Routes:** Blue Route, Light Blue Route, Dark Green Route, Light Green Route, Purple Route
- **Stop ID:** `female_classrooms`

### **Women's Activity Center** (C05)
- **Routes:** Blue Route, Light Blue Route, Dark Green Route, Light Green Route, Pink Route
- **Stop ID:** `womens_activity_center`

### **Library** (B13)
- **Routes:** Blue Route, Black Line, White Line, Brown Line
- **Stop ID:** `library`

### **College of Business and Economics** (H08)
- **Routes:** Blue Route, Black Line, White Line, Maroon Line
- **Stop ID:** `business`

### **College of Engineering** (H07)
- **Routes:** Light Blue Route, Black Line, White Line, Maroon Line, Orange Route
- **Stop ID:** `engineering`

### **New College of Education** (I10)
- **Routes:** Dark Green Route, Black Line, White Line
- **Stop ID:** `education`

### **College of Law** (I09)
- **Routes:** Light Green Route, Black Line, White Line, Orange Route
- **Stop ID:** `law`

### **Al Razi Building** (H12)
- **Routes:** Purple Route, Pink Route, Black Line
- **Stop ID:** `al_razi`

### **Ibn Al Baitar Building** (I06)
- **Routes:** Purple Route, Pink Route, Black Line
- **Stop ID:** `ibn_al_baitar`

### **Tamyuz Simulation Center** (I08)
- **Routes:** Orange Route, Black Line
- **Stop ID:** `tamyuz_center`

### **Student Affairs Building** (I11)
- **Routes:** Black Line, White Line
- **Stop ID:** `students_affairs`

### **Research Complex** (H10)
- **Routes:** Black Line, Brown Line
- **Stop ID:** `research_complex`

### **Information Technology Services** (B03)
- **Routes:** Black Line, White Line, Brown Line
- **Stop ID:** `it_services`

### **Men's Foundation Building** (A06)
- **Routes:** Black Line
- **Stop ID:** `mens_foundation`

### **Sports and Events Complex** (A07)
- **Routes:** Brown Line
- **Stop ID:** `sports_facilities`

---

## **Route Details by Route**

### **7 Horizontal Routes**

#### **1. Blue Route**
- **Stops:** Female Classrooms → Women's Activity → Library → Business
- **Duration:** 12 minutes
- **Color:** #1976D2 (Blue)

#### **2. Light Blue Route**
- **Stops:** Female Classrooms → Women's Activity → Engineering
- **Duration:** 10 minutes
- **Color:** #42A5F5 (Light Blue)

#### **3. Dark Green Route**
- **Stops:** Female Classrooms → Women's Activity → Education
- **Duration:** 8 minutes
- **Color:** #388E3C (Dark Green)

#### **4. Light Green Route**
- **Stops:** Female Classrooms → Women's Activity → Law
- **Duration:** 8 minutes
- **Color:** #66BB6A (Light Green)

#### **5. Purple Route**
- **Stops:** Female Classrooms → Al Razi → Ibn Al Baitar
- **Duration:** 10 minutes
- **Color:** #7B1FA2 (Purple)

#### **6. Pink Route**
- **Stops:** Women's Activity → Al Razi → Ibn Al Baitar
- **Duration:** 8 minutes
- **Color:** #C2185B (Pink)

#### **7. Orange Route**
- **Stops:** Tamyuz Simulation Center → Engineering → Law
- **Duration:** 10 minutes
- **Color:** #F57C00 (Orange)

---

### **4 Metro Lines**

#### **8. Black Line (Main Loop)**
- **Stops:** Metro Station → Ibn Al Baitar → Tamyuz Center → Law → Education → Student Affairs → Business → Engineering → Research Complex → Library → IT Services → Men's Foundation → Al Razi
- **Duration:** 25 minutes
- **Color:** #212121 (Black)
- **Description:** Complete campus tour

#### **9. White Line (Inner Loop)**
- **Stops:** Law → Education → Student Affairs → Business → Engineering → Library → IT Services
- **Duration:** 18 minutes
- **Color:** #FAFAFA (White)
- **Description:** Inner campus loop

#### **10. Brown Line (Research & Sports)**
- **Stops:** Metro Station → Research Complex → Library → IT Services → Sports Facilities
- **Duration:** 15 minutes
- **Color:** #5D4037 (Brown)
- **Description:** Research complex and sports facilities

#### **11. Maroon Line (Express)**
- **Stops:** Metro Station → Business → Engineering
- **Duration:** 8 minutes
- **Color:** #8D6E63 (Maroon)
- **Description:** Quick express route

---

## **Logic for Finding Routes Between Two Locations**

### **Current Implementation:**

1. **Location to Routes Mapping:**
   - Each `BusStop` has a `routes` array listing which routes serve it
   - Example: Library has `['blue_route', 'black_line', 'white_line', 'brown_line']`

2. **Route to Stops Mapping:**
   - Each `BusRoute` has a `stopIds` array listing which stops it visits
   - Example: Blue Route has `['female_classrooms', 'womens_activity_center', 'library', 'business']`

3. **Finding Connecting Routes:**
   - To find routes between Origin and Destination:
     1. Get all routes that serve the Origin location
     2. Get all routes that serve the Destination location
     3. Find the intersection (routes that serve BOTH)
     4. Return those routes as available buses

### **Example Logic:**
```
Origin: Library
- Routes: ['blue_route', 'black_line', 'white_line', 'brown_line']

Destination: Business
- Routes: ['blue_route', 'black_line', 'white_line', 'maroon_line']

Common Routes (serve both):
- blue_route ✓
- black_line ✓
- white_line ✓

Result: 3 routes connect Library → Business
```

### **Code Location:**
- **File:** `qu_bus_tracker/lib/bus_service.dart`
- **Function:** `getRoutesToDestination()` (lines 437-456)
- **Current Implementation:** Only checks destination routes (simplified)
- **Note:** The destination selection screen shows all active buses (not filtered by route logic yet)

---

## **Improvement Needed:**

The current `_getAvailableBuses()` function in `destination_selection_screen.dart` shows ALL active buses without filtering by route. To properly show only buses that connect Origin → Destination:

1. Get routes that serve Origin
2. Get routes that serve Destination  
3. Find intersection (routes serving both)
4. Filter buses to only show those on common routes

This would require:
- Matching location names to BusStop names
- Using BusService to get routes for each stop
- Filtering buses by route IDs

