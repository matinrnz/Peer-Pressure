# Social Network Analysis in Healthcare: Peer Pressure Simulation  
**Final Project | September 2025**  
Department of Industrial and Systems Engineering, Tarbiat Modares University  
- **Course**: Social Networks Analysis in Healthcare  
- **Professor**: Dr. Jalalimanesh  
- **Students**: Matineh Rangzan, Faezeh Zare, Paria Sadeghi  

---

## Overview
This repository hosts the final project for the **"Social Networks Analysis in Healthcare"** course. It contains two distinct implementations of a simulation designed to model the dynamics of substance use within a student peer network:

1. A detailed model in **NetLogo**  
2. An interactive **web-based version**  

Both simulations are based on the **SEUR (Susceptible, Experimenting, Using, Recovered)** model. Users take on the role of a school counselor with a limited budget, tasked with implementing interventions to minimize the rate of substance use among students.  

The project provides a practical understanding of how **social influence** impacts health-related behaviors.  
A live, playable version of the web simulation is hosted on **GitHub Pages**.

A live, playable version of the web simulation is hosted here:  
[Play the Web Simulation](https://matinrnz.github.io/Peer-Pressure/)  

---

## Key Features of the Web Simulation
- **Interactive D3.js Visualization**  
  The student social network is dynamically rendered, showing peer connections and individual states.  

- **SEUR Model Simulation**  
  The epidemiological SEUR model is adapted to social contagion dynamics.  

- **Strategic Gameplay**  
  Players must manage a budget and choose interventions (Education, Support Sessions, Outreach) to control the spread of substance use.  

- **Step-by-Step Tutorial**  
  A built-in tutorial explains each SEUR state and the core mechanics before the main challenge.  

- **Bilingual Interface**  
  Available in both **English** and **Persian (فارسی)**.  

---

## The Two Simulation Models
This repository contains **two versions** of the peer pressure simulation:

### 1. NetLogo Model (`PeerPressure.nlogo`)
- Designed for **scientific simulation and parameter tuning**.  
- Exposes all parameters (e.g., `peer-pressure-weight`, `relapse-prob`) through sliders.  
- Enables rapid testing and **in-depth experimentation**.  

### 2. Web-Based Simulation (`index.html`)
- A **direct adaptation** of the NetLogo model.  
- Focused on **accessibility** and a **game-like experience**.  
- Simplifies complex parameters into a **guided tutorial** and a **condensed four-month challenge**.  

---

## Comparing the Models

### Core Similarities
- **SEUR Framework**: Both use the Susceptible, Experimenting, Using, and Recovered states.  
- **Social Influence**: Peer influence drives state transitions.  
- **Interventions**: Education, support, and leadership by recovered students are featured in both.  

### Key Differences
- **Platform**: NetLogo (desktop) vs. Web (browser-based, JavaScript + D3.js).  
- **Interactivity**: NetLogo → sliders for experimentation; Web → narrative-driven tutorial.  
- **Complexity**: NetLogo has more granular parameters; Web version simplifies for gameplay.  
- **Timeframe**: NetLogo simulates **12 months**; Web simulation runs **4 months**.  

---

## Technologies Used
- **Web Simulation**: HTML5, CSS3, JavaScript (ES6), D3.js  
- **Original Model**: NetLogo  

---

## Inspiration
The web simulation was inspired by Nicky Case’s interactive guide *“The Wisdom and/or Madness of Crowds”* ([Crowds](https://ncase.me/crowds/)).   

---
This project was created for **educational purposes** as part of the curriculum at **Tarbiat Modares University**.  

---
