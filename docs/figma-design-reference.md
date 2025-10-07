# SwiftProxy Figma Design Reference

## Overview
This document captures the design specifications from the Figma mockup for the SwiftProxy application.

## Design Elements

### Main Window Layout
- **Window Size**: 1200x800px minimum
- **Split View**: Sidebar (250px) + Main Content Area

### Color Scheme
- **Primary Blue**: #007AFF (Apple system blue)
- **Success Green**: #34C759
- **Warning Orange**: #FF9500
- **Background**: System background color
- **Secondary Text**: #8E8E93

### Navigation Sidebar
- **Width**: 250px fixed
- **Items**:
  - Dashboard (chart.bar icon)
  - Connections (network icon)
  - Configuration (gearshape icon)
  - Statistics (chart.line.uptrend.xyaxis icon)

### Header Bar
- **Height**: 60px
- **Contents**:
  - App icon and title (left)
  - Status indicator (center-right)
  - Power toggle switch (right)

### Dashboard View
- **Stats Cards Grid**: 2x2 layout
  - Total Connections
  - Data Transferred
  - Active Rules
  - Uptime
- **Recent Activity Log**: List format with timestamps

### Connections View
- **Table Columns**:
  - Process Name
  - Host
  - Port
  - Status (with color indicator)
  - Data Transferred

### Configuration View
- **Form Sections**:
  - Basic Settings (Port, Protocol)
  - Authentication (Toggle + Username/Password fields)
  - Rules Management (List with checkboxes)
- **Action Buttons**: Save Configuration, Reset

### Statistics View
- **Traffic Chart**: Line graph visualization area
- **Metrics Grid**: 3x2 layout
  - Total Requests
  - Blocked
  - Success Rate
  - Avg Response
  - Peak Traffic
  - Total Data

## Typography
- **Large Title**: System font, 34pt, Bold
- **Title**: System font, 28pt, Semibold
- **Headline**: System font, 17pt, Semibold
- **Body**: System font, 13pt, Regular
- **Caption**: System font, 11pt, Regular

## Component Specifications

### Stat Cards
- **Size**: Flexible grid item
- **Padding**: 16px
- **Background**: Gray opacity 0.1
- **Border Radius**: 8px
- **Icon Size**: 20x20px

### Buttons
- **Primary**: Bordered prominent style
- **Secondary**: Bordered style
- **Height**: 32px
- **Padding**: 8px horizontal

### Form Controls
- **Text Fields**: Standard macOS style
- **Toggle Switches**: System toggle style
- **Segmented Control**: For protocol selection

### Table View
- **Row Height**: 32px
- **Alternating Row Colors**: System default
- **Selection Style**: Source list

## Interaction States
- **Hover**: Subtle highlight on interactive elements
- **Active**: Blue accent color for selected items
- **Disabled**: 50% opacity for inactive elements

## Animation Guidelines
- **Transitions**: 0.25s ease-in-out
- **Status Indicators**: Pulse animation for active state
- **Toggle Animations**: System default spring animation

---

*Note: This reference document was created based on the Figma design mockup for SwiftProxy. The actual implementation in SimpleSwiftProxyApp.swift follows these design specifications.*