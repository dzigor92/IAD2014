;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                   ;;
;;  IAD - Netlogo: Market Negotiation (DEFINITIVA)   ;;
;; ------------------------------------------------- ;;
;; authors: Igor Dzinka / Vicent Roig                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  market-benefit
  iteration
  min-energy-for-batna
  target-price
  orig-traders-num
  max-toughness
  negotiation-rounds
  initial-money
  initial-energy
]

breed [ traders trader ] ;; definimos un tipo de agente participante

traders-own [
  energy
  money
  toughness
  partnered?
  partner
  redline
  offer
  reached-agreement
  last-partner-offer
  var-money-energy-toughness?
  var-history-agreements-toughness?  
  negotiations-counter
  agreements-counter
  high-agreements
  low-agreements    
]


;;;;;;;;;;;;;;;;;;;;;;
;;;Setup Procedures;;;
;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  reset-ticks
  
  set max-toughness 10.0 ;; should be the same as the max-toughness in choosers!
  set iteration 0  
  set initial-money 50
  set initial-energy 50
  set min-energy-for-batna energy-loss-per-round
  set target-price (energy-price-one-buyer * 2) * (1 - discount-two-buyers / 100.0) ;; target price for 2 buyers after discount  
  setup-traders ;;setup the traders and distribute them randomly
  set orig-traders-num count traders
  do-plot  
end

;;setup the traders and distribute them randomly
to setup-traders
  make-traders ;;create the different turtle types
  
  ask traders [ ifelse toughness = "var-money-energy" [ set var-money-energy-toughness? true set toughness 4.5 ] [ set var-money-energy-toughness? false ] ]
  ask traders [ ifelse toughness = "var-history-agreements" [ set var-history-agreements-toughness? true set toughness 4.5 ] [ set var-history-agreements-toughness? false ] ]
  ask traders [ if toughness = "discount-dep" [ set toughness   (1 - discount-two-buyers / 100) * max-toughness - 0.5 ] ]
  setup-common-variables ;;sets the variables that all traders share
end

;;create the different turtle types
to make-traders
  set-default-shape traders "person"
  ask n-of initial-num-blue patches[
    sprout-traders 1 [
      set color blue
      set toughness blue-toughness
    ]
  ]
  ask n-of initial-num-green patches[
    sprout-traders 1 [
      set color green
       set toughness green-toughness
    ]
  ]
  ask n-of initial-num-red patches[
    sprout-traders 1 [
      set color red
       set toughness red-toughness
    ]
  ]
end

;;set the variables that all traders share
to setup-common-variables
  ask traders [ init-turtle-common ]
  ask traders [setxy random-xcor random-ycor]
end

to init-turtle-common
  set money initial-money
  set energy initial-energy
  set partnered? false
  set partner nobody
  set redline 0
  set offer 0
  set reached-agreement false
  set last-partner-offer 0
  set negotiations-counter 0
  set agreements-counter 0            
  set  high-agreements 0
  set low-agreements  0
  rt random-float 360
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;;Runtime Procedures;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to go
  without-interruption [ clear-last-round ]
  ask traders [ if energy <= 0 [ die ]]                                                  ;;traders with no energy die
 
  set iteration iteration + 1
  ask traders with [ energy > min-energy-for-batna ] [ partner-up ]  ;;have traders try to find a partner with energy > min-energy-for-batna
  partnered-negotiate
  let non-partnered-traders traders with [ partnered? = false ]
  ask non-partnered-traders [ buy-alone-if-needed ]
  ask traders [ set money money + money-gain-per-round ]         ;;add regular money-gain
  ask traders [ set energy energy - energy-loss-per-round ]   ;;deduct regular energy loss
  do-plot
end

to clear-last-round
  let partnered-traders traders with [ partnered? ]
  ask partnered-traders [ 
    set offer 0
    set redline 0
    set reached-agreement false
    set last-partner-offer 0
    release-partners 
  ]
  ask traders [ set label ""  ]
  ask patches with [pcolor !=  black] [ set pcolor black ]
end

;;release partner and turn around to leave
to release-partners
  set partnered? false
  set partner nobody
  rt 180
end

;;have traders try to find a partner
;;This will be done using without-interruption.
;;This is so that other traders can't act while one is trying to partner up.
;;Also, since other traders that have already executed partner-up may have
;;caused the turtle executing partner-up to be partnered,
;;a check is needed to make sure the calling turtle isn't partnered.

to partner-up ;;turtle procedure
  without-interruption [                  ;;we don't want other traders acting
    ifelse(not partnered?) [              ;;make sure still not partnered
      rt (random-float 90 - random-float 90) fd 1     ;;move around randomly
      set partner one-of (traders-at -1 0) with [ not partnered? and energy > min-energy-for-batna ]
      if partner != nobody [              ;;if successful grabbing a partner, partner up
        set partnered? true
        ask partner [set (partnered?) true] 
        ask partner [ set partner myself ]
        set heading 270                   ;;face partner
        ask partner [set heading 90]
      ]
    ]
    []                                    ;;if partnered, don't do anything
  ]
end

; have partnered traders negotiate
to partnered-negotiate
  let min-list list ( orig-traders-num) (count traders with [ partnered? ])
  let negotiating-traders-num min min-list
  let partnered-traders n-of negotiating-traders-num traders with [ partnered? ]   ;limit number of negotiations in one round to avoid population explosion
  ask partnered-traders with [ var-money-energy-toughness? ] [ calculate-var-money-energy-toughenss ]
  ask partnered-traders [  set-redline ]
  set negotiation-rounds (random 10) + 1 ;random num of negotiation rounds to avoid tight coupling between toughness and number of rounds needed for agreement
  repeat negotiation-rounds [
    ask partnered-traders [ get-partner-last-offer ]
    ask partnered-traders [ make-offer ]  
    ask partnered-traders [ check-for-agreement ]
  ] 
  ask partnered-traders [ 
    if reached-agreement
    [
      ask patch-here [ set pcolor pink ]
      
      set market-benefit market-benefit + offer * 0.15
      let earnings  offer - 0.15 * offer
      set money money + earnings
      
      fix-residue
      make-transaction
    ]
  ]
  ask partnered-traders with [ var-history-agreements-toughness? ] [ calculate-var-history-agreements-toughenss ] 
end

to set-redline
  set redline (target-price / 2.0 ) * ( 1 + ( max-toughness - toughness) / max-toughness ) 
  if redline > energy-price-one-buyer [ set redline energy-price-one-buyer ]
end

to get-partner-last-offer
  set last-partner-offer [offer] of partner
end

to make-offer
  if reached-agreement = false
  [
    let min-list list ( ( offer + (redline - offer) / toughness)) money 
    set offer min min-list
  ]
end

to check-for-agreement
  if reached-agreement = false
  [
    if ((offer + [offer] of partner) >= target-price) 
    [
      set reached-agreement true
    ]
  ]
end

to fix-residue
  without-interruption [ 
    ;; if offers passed the target price, remove the residue from both offers 
    ;; (first turtle of the pair will do this residue fix for both of them. When the other turtle
    ;; will do the same check, there will be no residue anymore)
    let residue (offer + [offer] of partner - target-price)
    set offer (offer - residue / 2.0)
    ask partner [set offer offer - residue / 2.0 ]
  ]  
end

to make-transaction
  set money (money - offer)
  set energy (energy + energy-units-in-pack)
  set label (precision offer  0)
end

to buy-alone-if-needed
  if ((energy <= min-energy-for-batna) and (money >= energy-price-one-buyer))
  [
    set money (money - energy-price-one-buyer)
    set energy (energy + energy-units-in-pack)
    set label energy-price-one-buyer
  ]
end

; Calculate toughness for traders with a toughness of "var-history-agreements" (toughness is set according to the history of previous agreements).
; Aiming to have agreements in which my offer is identical to the partner's offer (not too low in order not to waste money, and not too high so 
; that enough agreements will be reached).
to calculate-var-history-agreements-toughenss
  if reached-agreement
  [
    set agreements-counter agreements-counter + 1
    if offer > [offer] of partner [ set high-agreements high-agreements + 1]
    if offer < [offer] of partner [ set low-agreements low-agreements + 1]
  ]
  if agreements-counter >= 18
  [
    if high-agreements > low-agreements 
    [ if toughness < max-toughness [ set toughness toughness + 0.5 ] ]
    if high-agreements < low-agreements 
    [ if toughness > 1 [ set toughness toughness - 0.5 ] ]
    
    set agreements-counter 0     
    set high-agreements 0
    set low-agreements 0    
  ]
end 

; Calculate toughenss for traders with a toughness of "var-money-energy" (toughness is set according to the amount of money and energy that the turtle has).
; The less money an turtle has, the tougher it is and vice-versa. The less energy an turtle has, the less-tough it is and vice-versa.
to calculate-var-money-energy-toughenss
  let normalized-money ( money * money-gain-per-round )
  let normalized-energy  (energy / energy-loss-per-round )
  set toughness 4.5
  if normalized-money > (energy-price-one-buyer * 3) [ set toughness toughness - 1 ]
  if normalized-money > (energy-price-one-buyer * 5) [ set toughness toughness - 1 ]      
  if normalized-money > (energy-price-one-buyer * 8) [ set toughness toughness - 1 ]            
  if normalized-money < (energy-price-one-buyer * 2) [ set toughness toughness + 1 ]                  
  if normalized-money < energy-price-one-buyer [ set toughness toughness + 1 ]                        
  if normalized-energy < (2 * initial-energy) * 0.07 [ set toughness toughness - 1 ]
  if normalized-energy > (2 * initial-energy) * 0.8 [ set toughness toughness + 1 ]                
end

to do-plot
  set-current-plot "number-of-agents"
  set-current-plot-pen "blue"
  let num count traders with [ color = blue ]
  if num > 0 [ plot num ] 
  set-current-plot-pen "green"
  set num count traders with [ color = green ]  
  if num > 0 [ plot num ] 
  set-current-plot-pen "red"
  set num count traders with [ color = red]  
  if num > 0 [ plot num ] 
  
  set-current-plot "average-money"
  set-current-plot-pen "blue"
  let money-list [ money ] of traders with [ color = blue ] 
  if not empty? money-list [ plot mean money-list ]
  set-current-plot-pen "red"
  set money-list [ money ] of traders with [ color = red ] 
  if not empty? money-list [ plot mean money-list ]
  set-current-plot-pen "green"
  set money-list [ money ] of traders with [ color = green ] 
  if not empty? money-list [ plot mean money-list ] 
  
  ;;plot for market benefeit progress
  set-current-plot "market-benefits-plot"
  set-current-plot-pen "default"
  plot market-benefit
end
@#$#@#$#@
GRAPHICS-WINDOW
554
10
984
461
10
10
20.0
1
14
1
1
1
0
1
1
1
-10
10
-10
10
0
0
1
ticks
30.0

BUTTON
171
16
234
49
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
276
16
338
49
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
268
77
442
110
money-gain-per-round
money-gain-per-round
0
10
1
1
1
NIL
HORIZONTAL

SLIDER
268
112
442
145
energy-loss-per-round
energy-loss-per-round
0
10
1
1
1
NIL
HORIZONTAL

SLIDER
73
94
247
127
energy-price-one-buyer
energy-price-one-buyer
1
100
33
1
1
NIL
HORIZONTAL

CHOOSER
259
181
397
226
blue-toughness
blue-toughness
1 2 3 4 5 6 7 8 9 10 "discount-dep" "var-money-energy" "var-history-agreements"
4

CHOOSER
259
281
397
326
red-toughness
red-toughness
1 2 3 4 5 6 7 8 9 10 "discount-dep" "var-money-energy" "var-history-agreements"
5

CHOOSER
259
231
397
276
green-toughness
green-toughness
1 2 3 4 5 6 7 8 9 10 "discount-dep" "var-money-energy" "var-history-agreements"
3

SLIDER
84
188
256
221
initial-num-blue
initial-num-blue
0
20
15
1
1
NIL
HORIZONTAL

SLIDER
84
237
256
270
initial-num-green
initial-num-green
0
20
15
1
1
NIL
HORIZONTAL

SLIDER
84
285
256
318
initial-num-red
initial-num-red
0
20
15
1
1
NIL
HORIZONTAL

SLIDER
73
129
247
162
discount-two-buyers
discount-two-buyers
10
90
35
1
1
%
HORIZONTAL

PLOT
16
343
188
483
number-of-agents
time
number-of-agents
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"blue" 1.0 0 -13345367 true "" ""
"green" 1.0 0 -10899396 true "" ""
"red" 1.0 0 -2674135 true "" ""

PLOT
192
343
362
484
average-money
time
money
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"blue" 1.0 0 -13345367 true "" ""
"green" 1.0 0 -10899396 true "" ""
"red" 1.0 0 -2674135 true "" ""

SLIDER
73
58
247
91
energy-units-in-pack
energy-units-in-pack
1
100
22
1
1
NIL
HORIZONTAL

PLOT
365
338
565
488
market-benefits-plot
time
benefits
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

@#$#@#$#@
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

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
