# Scheduler's Labyrinth - 10-Minute Group Presentation Guide

## Overview (10 members, 10 minutes total)

### Time Allocation
- **Introduction** (1 min) - 1 person
- **Game Concept & Educational Value** (1.5 min) - 1 person  
- **Technical Architecture** (2 min) - 2 people
- **Scheduling Algorithms Demo** (3 min) - 3 people
- **Features & Polish** (1.5 min) - 2 people
- **Q&A Buffer** (1 min)

---

## Detailed Script (Share among group)

### **Speaker 1 - Introduction (1 min)**
"Welcome to Scheduler's Labyrinth, an interactive educational game that teaches Operating Systems scheduling algorithms. We created this as our finals project to make complex concepts—FCFS, Priority Scheduling, and Round Robin—accessible and engaging through gamified combat encounters."

### **Speaker 2 - Game Concept (1.5 min)**
"The game features three difficulty stages, each representing a different scheduling algorithm. Players answer strategic scheduling questions in real-time combat scenarios:
- **Easy (FCFS)**: First-Come-First-Served - straightforward sequential ordering
- **Medium (Priority)**: Priority Scheduling - managing process priorities
- **Hard (Round Robin)**: Round Robin - time-slice allocation

Correct answers damage enemies; wrong answers cost player health. It's 'Dark Souls meets Operating Systems.'"

### **Speaker 3 - Technical Overview Pt 1 (1 min)**
"Our tech stack: We built this in Godot 4.2 using GDScript. The architecture separates concerns into modules:
- **Player System**: State machine handling idle, running, jumping, crouching
- **Enemy System**: Three unique enemies (Slime, Dragon, Necromancer) each implementing their algorithm
- **Battle System**: Question generation, answer validation, dynamic feedback
- **Scene Management**: Centralized transitions between menu, battle, and level scenes

All code follows clean architecture with signal-based communication."

### **Speaker 4 - Technical Overview Pt 2 (1 min)**
"Key technical highlights:
- **Procedural Question Generation**: Algorithms dynamically create scheduling questions with different parameters
- **Gantt Chart Visualization**: Real-time visualization of process scheduling showing the correct answer
- **Persistent State**: Player progress carries across stages with difficulty scaling
- **Input Handling**: Keyboard and mouse support with accessible keyboard shortcuts for quick answers

The codebase is modular—each system is independent and easily extensible."

### **Speaker 5 - FCFS Algorithm Demo (1 min)**
[Live demo or screenshot walkthrough]
"First-Come-First-Served is the simplest algorithm. Processes execute in arrival order. Our Slime enemy uses this. Questions ask: 'In what order do these processes complete?' Players answer with a sequence. The Gantt chart shows the timeline—every process gets a contiguous block. This teaches students the FCFS weakness: long-waiting times for later processes."

### **Speaker 6 - Priority Scheduling Demo (1 min)**
"Priority Scheduling assigns priority values. Higher priority = executes first. Our Necromancer uses this. Questions involve calculations like 'Which process executes at time 5?' with multiple priority levels. The visualization clearly shows priority-based preemption. This teaches real-world scheduling where some tasks matter more."

### **Speaker 7 - Round Robin Demo (1 min)**
"Round Robin allocates fixed time slices (quantum). Our Dragon enemy implements this. Questions ask about context switches and timing. For example: 'After 2 time slices, which process is running?' The Gantt chart shows color-coded time slices. This teaches how modern systems handle fairness—every process gets equal CPU time."

### **Speaker 8 - Game Features (1 min)**
"Features we've implemented:
- **Multiple Question Types**: Fill-in-the-blank answers, sequence ordering, timing prediction
- **Dynamic Difficulty**: Wrong answers make enemies stronger; correct answers grant strategic advantages
- **Detailed Explanations**: Toggle-able expert explanations showing exactly why an answer is right
- **Visual Feedback**: Screen shake on damage, floating damage numbers, smooth animations
- **Keyboard Accessibility**: Press 1-3 for quick multiple-choice answers, Enter to submit"

### **Speaker 9 - Polish & UX (0.5 min)**
"We prioritized user experience:
- Clean UI with responsive design
- Accessible keyboard-first controls
- Persistent configuration system for balancing difficulty
- Error messaging that teaches—wrong answers highlight which part of the reasoning was incorrect
- Smooth animations and visual feedback for every action

The game teaches while entertaining."

### **Speaker 10 - Closing & Q&A (0.5 min)**
"Scheduler's Labyrinth bridges the gap between theoretical OS concepts and practical understanding through interactive gameplay. We're excited to take your questions. What would you like to know?"

---

## Visual Aids to Prepare

### Slide 1: Title
- Game logo
- Team members

### Slide 2: Problem Statement
- "Students struggle to visualize scheduling algorithms"
- Screenshot of traditional textbook explanation
- Screenshot of our game

### Slide 3: Three Algorithms Overview
- Comparison table: FCFS vs Priority vs Round Robin
- Key differences highlighted

### Slide 4: Game Screenshot
- Battle screen with question and Gantt chart

### Slide 5: Architecture Diagram
- Simple boxes: Player → Battle System → Enemy
- Showing signal flow

### Slide 6: Demo Schedule
- Indicate which speakers will demo

### Slide 7: Key Features Checklist
- ✓ Procedural generation
- ✓ Real-time visualization
- ✓ Difficulty scaling
- ✓ Multiple question types

### Slide 8: Technical Stack
- Godot 4.2
- GDScript
- Clean architecture

### Slide 9: Lessons & Takeaways
- Students learn by doing (Bloom's Taxonomy)
- Visual + interactive = better retention

### Slide 10: Thank You / Q&A

---

## Tips for Success

1. **Practice together** - Run through the script 2-3 times before presenting
2. **Synchronize demos** - Designate one person as "demo driver" who shares screen
3. **Speaker transitions** - Have smooth handoffs: "Now let me hand it over to [Name] who'll show the difficulty system"
4. **Engagement** - Ask a question like "Who can guess which algorithm the Dragon uses?" 
5. **Time management** - Have a timekeeper signaling at 5-min and 8-min marks
6. **Backup slides** - Prepare extra slides on: scalability, future improvements, code metrics

---

## Backup Content (if time allows)

### Extended Features
- "We're planning a campaign mode where players unlock increasingly difficult scenarios"
- "Future versions will include a leaderboard and competitive multiplayer"
- "The procedural generation ensures no two battles are identical"

### Code Metrics
- Lines of code: ~2,500
- Number of classes: 15+
- Test coverage: Unit tests for algorithm generators

### Performance
- Runs at 60 FPS on standard hardware
- Supports resolution scaling
- Minimal memory footprint

---

## Post-Presentation Talking Points

If asked "What would you do differently?":
- "We'd add a tutorial mode from the start instead of relying on intuition"
- "More extensive animations for visual learners"
- "Multiplayer scenarios where players compete on the same scheduling problem"

If asked "How does this scale?":
- "The architecture supports adding new scheduling algorithms easily—just create a new generator"
- "Question repository can grow to thousands with procedural variations"
- "Could expand to process synchronization, deadlock, paging algorithms"

---

## Member Assignments

Assign these roles:

| Role | Speaker(s) | Duration |
|------|-----------|----------|
| Intro | [Name] | 1 min |
| Concept | [Name] | 1.5 min |
| Tech Pt1 | [Name] | 1 min |
| Tech Pt2 | [Name] | 1 min |
| FCFS Demo | [Name] | 1 min |
| Priority Demo | [Name] | 1 min |
| RR Demo | [Name] | 1 min |
| Features | [Name] | 1 min |
| Polish | [Name] | 0.5 min |
| Q&A / Closer | [Name] | 0.5 min |
| Timekeeper | [Name] | - |
| Demo Driver | [Name] | - |

---

## Presentation Confidence Boosters

- **Know your algorithm deeply** - Each speaker should understand their assigned algorithm inside-out
- **Practice the demo** - Test the game build before presenting to avoid crashes
- **Speak with conviction** - You built something impressive; own it
- **Tell the story** - Frame it as "We solved a real problem" not "Here's a school project"

Good luck with your presentation! 🚀
