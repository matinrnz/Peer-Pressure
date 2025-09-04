; =========================================================
; Peer Pressure SEUR  — Monthly decision game + BehaviorSpace-safe
; =========================================================
; S (Susceptible)  E (Experimenting)  U (Using)  R (Recovered)
; Win: After Month 12, Using% < year-win-threshold (default 15%).
; Instant loss: if Using% >= lose-U-threshold at any time.
; =========================================================

globals [
  nS nE nU nR
  budget status
  month months-per-year last-month-U
  edu-remaining support-remaining
  cd-edu cd-support cd-leaders cd-outreach
  start-budget
  edu-cost edu-duration edu-effect
  support-cost support-duration support-bonus
  leaders-cost leaders-count leader-buffer leader-cooldown
  outreach-cost outreach-success outreach-cooldown
  silent?                          ;; << turn popups off for BehaviorSpace
]

turtles-own [ state e-left is-leader? ]
undirected-link-breed [friendships friendship]

; ---------- utility: safe messaging ----------
to msg [txt]
  if not silent? [ user-message txt ]
end

; ---------- reporters for BehaviorSpace ----------
to-report percentU
  report 100 * nU / count turtles
end

to run-year
  while [month <= 12 and status = "Running"] [
    run-month
  ]
end
; ------------------------------------------------

; ---------------- SETUP ----------------
to setup
  clear-all
  set-default-shape turtles "circle"
  set silent? false                            ;; normal play shows messages

  ;; ===== Tunable config =====
  set start-budget 50
  set edu-cost 10
  set edu-duration 30
  set edu-effect 0.40

  set support-cost 8
  set support-duration 25
  set support-bonus 0.12

  set leaders-cost 12
  set leaders-count 6
  set leader-buffer 0.30
  set leader-cooldown 30

  set outreach-cost 6
  set outreach-success 0.60
  set outreach-cooldown 10
  ;; ==========================

  ;; World
  create-turtles num-students [
    setxy random-xcor random-ycor
    set size 1.2
    set state "S"
    set is-leader? false
    recolor
  ]
  ask n-of round (num-students * initial-using-percent / 100) turtles [
    set state "U"  recolor
  ]

  if num-students > 1 [
    let p (avg-degree / (num-students - 1))
    ask turtles [
      ask other turtles with [who > [who] of myself] [
        if random-float 1 < p [ create-friendship-with myself ]
      ]
    ]
  ]
  layout-circle sort turtles (max-pxcor - 2)

  ;; monthly calendar init
  set months-per-year 12
  set month 1
  if not is-number? month-length       [ set month-length 10 ]
  if not is-number? year-win-threshold [ set year-win-threshold 15 ]

  ;; timers & budget
  set budget start-budget
  set status "Running"
  set edu-remaining 0
  set support-remaining 0
  set cd-edu 0
  set cd-support 0
  set cd-leaders 0
  set cd-outreach 0

  update-counts
  set last-month-U (100 * nU / count turtles)

  my-setup-plots
  reset-ticks
end

; ---------------- ONE TICK ----------------
to step
  if edu-remaining > 0     [ set edu-remaining edu-remaining - 1 ]
  if support-remaining > 0 [ set support-remaining support-remaining - 1 ]
  if cd-edu > 0            [ set cd-edu cd-edu - 1 ]
  if cd-support > 0        [ set cd-support cd-support - 1 ]
  if cd-leaders > 0        [ set cd-leaders cd-leaders - 1 ]
  if cd-outreach > 0       [ set cd-outreach cd-outreach - 1 ]

  ask turtles [
    if state = "S" [ s-step ]
    if state = "E" [ e-step ]
    if state = "U" [ u-step ]
    if state = "R" [ r-step ]
  ]

  layout-spring turtles friendships 0.2 0.3 1.5

  update-counts
  do-plots
  check-instant-loss
  tick
end

; ---------------- MONTH ADVANCE ----------------
to run-month
  if not any? turtles [ stop ]
  if status != "Running" [ stop ]
  if month > months-per-year [ stop ]

  let i 0
  while [i < month-length and status = "Running"] [
    step
    set i i + 1
  ]
  if status != "Running" [ stop ]  ;; may stop by instant loss

  ;; local Using% for this month
  let uPct percentU
  let trend
    (ifelse-value uPct > last-month-U
      [ "↑ worse" ]
      [ ifelse-value uPct < last-month-U
          [ "↓ better" ]
          [ "→ same" ] ])

  msg (word "Month " month " report: Using " (round uPct)
             "% (" trend ").  Budget " budget ".")

  set last-month-U uPct
  set month month + 1

  if month > months-per-year [
    ifelse uPct < year-win-threshold
      [ set status (word "Year complete — You Win! Using "
                         (round uPct) "% < target " year-win-threshold "%.") ]
      [ set status (word "Year complete — You Lose. Using "
                         (round uPct) "% ≥ target " year-win-threshold "%.") ]
    msg status
    stop
  ]
end

; ---------------- DYNAMICS ----------------
to s-step
  let deg count link-neighbors
  if deg = 0 [
    if random-float 1 < base-initiation-prob [ become-E ]
    stop
  ]

  let fracU (count link-neighbors with [state = "U"] / deg)
  let buffer (ifelse-value any? link-neighbors with [is-leader?] [leader-buffer] [0])
  let perceived max list 0 (fracU - buffer)

  let weight (ifelse-value (edu-remaining > 0)
                [ peer-pressure-weight * (1 - edu-effect) ]
                [ peer-pressure-weight ])

  let pressure weight * (perceived - threshold)
  let p clamp01 (base-initiation-prob + max list 0 pressure)
  if random-float 1 < p [ become-E ]
end

to e-step
  set e-left e-left - 1
  if e-left <= 0 [
    ifelse random-float 1 < prob-E-to-U
      [ set state "U" ]
      [ set state "S" ]
    recolor
  ]
end

to u-step
  let p (recovery-prob + (ifelse-value (support-remaining > 0) [support-bonus] [0]))
  if random-float 1 < clamp01 p [
    set state "R"
    recolor
  ]
end

to r-step
  if random-float 1 < relapse-prob [
    set state "U"
    recolor
  ]
end

; ---------------- INSTANT LOSS ----------------
to check-instant-loss
  let uPct percentU
  if uPct >= lose-U-threshold [
    set status (word "Game Over — Using hit " (round uPct) "%.")
    msg status
    stop
  ]
end

; ---------------- ACTIONS (use between months) ----------------
to action-education
  if cd-edu > 0 [ msg (word "Education on cooldown (" cd-edu " ticks).") stop ]
  if budget < edu-cost [ msg "Not enough budget for Education." stop ]
  set budget budget - edu-cost
  set edu-remaining edu-duration
  set cd-edu 15
  msg (word "Education launched for " edu-duration " ticks (budget " budget ").")
end

to action-support
  if cd-support > 0 [ msg (word "Support on cooldown (" cd-support " ticks).") stop ]
  if budget < support-cost [ msg "Not enough budget for Support." stop ]
  set budget budget - support-cost
  set support-remaining support-duration
  set cd-support 15
  msg (word "Support launched for " support-duration " ticks (budget " budget ").")
end

to action-recruit-leaders
  if cd-leaders > 0 [ msg (word "Recruit on cooldown (" cd-leaders " ticks).") stop ]
  if budget < leaders-cost [ msg "Not enough budget to recruit leaders." stop ]

  let pool turtles with [state != "U" and not is-leader?]
  ifelse any? pool [
    let chosen nobody
    let n min list leaders-count count pool
    let tmp pool
    repeat n [
      let t max-one-of tmp [count link-neighbors]
      set chosen (turtle-set chosen t)
      set tmp tmp with [self != t]
    ]
    ask chosen [
      set is-leader? true
      set shape "star"
      set size 1.4
    ]
    set budget budget - leaders-cost
    set cd-leaders leader-cooldown
    msg (word "Recruited " count chosen " peer leaders (budget " budget ").")
  ] [
    msg "No eligible students to recruit."
  ]
end

to action-outreach
  if cd-outreach > 0 [ msg (word "Outreach on cooldown (" cd-outreach " ticks).") stop ]
  if budget < outreach-cost [ msg "Not enough budget for Outreach." stop ]

  let users turtles with [state = "U"]
  if not any? users [ msg "No current users to target." stop ]

  let target max-one-of users [count link-neighbors]
  ifelse random-float 1 < outreach-success [
    ask target [ set state "R" recolor ]
    msg "Outreach succeeded: target recovered."
  ] [
    msg "Outreach attempt failed."
  ]
  set budget budget - outreach-cost
  set cd-outreach outreach-cooldown
end

; ---------------- HELPERS ----------------
to become-E
  set state "E"
  set e-left experiment-length
  recolor
end

to recolor
  if is-leader? [
    set shape "star"
    set size 1.4
  ]
  if not is-leader? [
    set shape "circle"
    set size 1.2
  ]
  if state = "S" [ set color 98 ]
  if state = "E" [ set color yellow + 1 ]
  if state = "U" [ set color red + 1 ]
  if state = "R" [ set color green + 2 ]
end

to update-counts
  set nS count turtles with [state = "S"]
  set nE count turtles with [state = "E"]
  set nU count turtles with [state = "U"]
  set nR count turtles with [state = "R"]
end

to-report clamp01 [x]
  report max list 0 min list 1 x
end

; ---------------- PLOTTING ----------------
to my-setup-plots
  set-current-plot "Prevalence"
  set-plot-x-range 0 (months-per-year * month-length)
  set-plot-y-range 0 count turtles
  set-current-plot-pen "S" plot-pen-reset
  set-current-plot-pen "E" plot-pen-reset
  set-current-plot-pen "U" plot-pen-reset
  set-current-plot-pen "R" plot-pen-reset

  set-current-plot "Using (%)"
  set-plot-x-range 0 (months-per-year * month-length)
  set-plot-y-range 0 100
end

to do-plots
  set-current-plot "Prevalence"
  set-current-plot-pen "S" plot nS
  set-current-plot-pen "E" plot nE
  set-current-plot-pen "U" plot nU
  set-current-plot-pen "R" plot nR

  set-current-plot "Using (%)"
  plotxy ticks (100 * nU / count turtles)
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
722
523
-1
-1
15.3
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
69
29
132
62
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
69
66
161
99
Next month
run-month
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
108
187
141
num-students
num-students
20
400
100.0
10
1
NIL
HORIZONTAL

SLIDER
15
142
187
175
avg-degree
avg-degree
0
12
4.0
1
1
NIL
HORIZONTAL

SLIDER
15
176
187
209
initial-using-percent
initial-using-percent
0
30
10.0
1
1
NIL
HORIZONTAL

SLIDER
15
210
187
243
threshold
threshold
0
1
0.4
0.05
1
NIL
HORIZONTAL

SLIDER
15
244
187
277
peer-pressure-weight
peer-pressure-weight
0
0.8
0.25
0.05
1
NIL
HORIZONTAL

SLIDER
15
278
187
311
base-initiation-prob
base-initiation-prob
0
0.05
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
15
312
187
345
prob-E-to-U
prob-E-to-U
0
1
0.4
0.05
1
NIL
HORIZONTAL

SLIDER
15
347
187
380
recovery-prob
recovery-prob
0
0.3
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
15
381
187
414
relapse-prob
relapse-prob
0
0.2
0.03
0.01
1
NIL
HORIZONTAL

SLIDER
15
416
187
449
experiment-length
experiment-length
0
20
4.0
1
1
NIL
HORIZONTAL

PLOT
889
12
1253
295
Prevalence
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"S" 1.0 0 -13791810 true "" ""
"E" 1.0 0 -4079321 true "" ""
"U" 1.0 0 -2674135 true "" ""
"R" 1.0 0 -14439633 true "" ""

MONITOR
1270
149
1366
194
Using
nU
17
1
11

MONITOR
1269
101
1366
146
Experimenting
nE
17
1
11

MONITOR
1270
196
1366
241
Recovered
nR
17
1
11

PLOT
889
300
1253
495
Using (%)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
1268
53
1366
98
Susceptible
nS
17
1
11

BUTTON
234
530
351
563
education (10)
action-education
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
357
530
463
563
support (8)
action-support
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
467
530
606
563
recruit leaders (12)
action-recruit-leaders
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
611
530
707
563
outreach (6)
action-outreach
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
780
80
837
125
budget
budget
17
1
11

MONITOR
244
621
336
666
edu-remaining
edu-remaining
17
1
11

MONITOR
354
621
466
666
support remaining
support-remaining
17
1
11

MONITOR
262
572
319
617
cd-edu
cd-edu
17
1
11

MONITOR
368
572
441
617
cd-support
cd-support
17
1
11

MONITOR
503
572
574
617
cd-leaders
cd-leaders
17
1
11

MONITOR
610
573
690
618
cd-outreach
cd-outreach
17
1
11

SLIDER
15
452
187
485
month-length
month-length
5
50
30.0
5
1
NIL
HORIZONTAL

SLIDER
14
487
186
520
year-win-threshold
year-win-threshold
5
50
15.0
5
1
NIL
HORIZONTAL

SLIDER
15
523
187
556
lose-U-threshold
lose-U-threshold
1
50
30.0
1
1
NIL
HORIZONTAL

MONITOR
765
27
851
72
month (1-12)
month
17
1
11

MONITOR
1369
148
1454
193
last-month-U
last-month-U
17
1
11

TEXTBOX
737
149
886
224
S (Susceptible)      Blue\nE (Experimenting)  Yellow\nU (Using)              Red\nR (Recovered)       Green
12
103.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="baseline" repetitions="30" runMetricsEveryStep="false">
    <setup>setup
set silent? true</setup>
    <go>run-year</go>
    <exitCondition>month &gt;= 12 or status != "Running"</exitCondition>
    <metric>ticks</metric>
    <metric>month</metric>
    <metric>nS</metric>
    <metric>nE</metric>
    <metric>nU</metric>
    <metric>nR</metric>
    <metric>percentU</metric>
    <metric>budget</metric>
    <metric>status</metric>
    <runMetricsCondition>(ticks mod month-length = 0) or (month &gt; 12) or (status != "Running")</runMetricsCondition>
    <enumeratedValueSet variable="prob-E-to-U">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="month-length">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="peer-pressure-weight">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lose-U-threshold">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="year-win-threshold">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="relapse-prob">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-initiation-prob">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-degree">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-students">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-prob">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="experiment-length">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-using-percent">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold">
      <value value="0.4"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
