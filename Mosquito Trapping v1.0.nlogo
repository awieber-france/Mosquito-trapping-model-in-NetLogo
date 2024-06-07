;----------------------------------------------------------------;
;--------------------------------VARIABLE DEFINITIONS--------------------------------;
;----------------------------------------------------------------;
breed [traps trap]
breed [tiger-mosquitos tiger-mosquito] ;aedes-albopictus
breed [humans human]
breed [houses house]
breed [chem-transporters chem-transporter]
breed [decors decor]
breed [properties property]
breed [wind-vanes wind-vane]

traps-own
[
  trapchem-release-rate
  num-trapped
]

chem-transporters-own
[
  nb-moves
  co2-mmoles
  carboxyl-mmoles
  trapchem-mmoles
]

tiger-mosquitos-own
[
  sex
  bite-probability
  lifecycle-stage
  minutes-in-lifecycle
  nb-of-bites
  fraction-full-of-blood
  trapchem-on
  co2-on
  carboxyl-on
  choice-of-direction
]

humans-own
[
  nb-of-bites
  co2-prod
  carboxylic-prod
]
patches-own
[
  pCO2-mmoles-per-m3
  pcarboxyl-mmoles-per-m3
  ptrapchem-mmoles-per-m3
  pgradient-orientation-trapchem
  pgradient-magnitude-trapchem
  pgradient-orientation-co2
  pgradient-magnitude-co2
  pgradient-orientation-carboxyl
  pgradient-magnitude-carboxyl
]

globals [
  ;General parameters
  background-color
  chemical-steps-per-minute
  air-pressure
  house-list
  humans-per-house
  setup-finished
  calibration-mosquito-count
  calibration-avg-population
  calibration-start-tick

  ;Distance, Size and Volume parameters
  scale
  radius-for-chem-concentration
  patch-height
  patch-volume
  human-max-dist-from-house
  human-min-dist-from-house

  ;Wind settings
  prev-scale-parameter
  prev-shape-parameter
  speed-samples
  wind-speed

  ;Mosquito specific parameters
  bite-distance
  vmin-mosquito
  vmax-mosquito
  trapping-rate
  trapping-distance
  filling-per-bite-min
  filling-per-bite-max
  minutes-spent-in-post-meal
  human-killing-proficiency
  natural-death-rate
  fraction-spawned-at-border

  ;General chemical parameters
  millimoles-per-patch
  chemical-diffusion-dist

  ;Trap chemical parameters
  trapchem-diffusion-dist
  trap-lambda
  trapchem-csat
  trapchem-detection-limit

  ;CO2 parameters
  co2-diffusion-dist
  co2-detection-limit-delta
  co2-mmoles-background
  co2-mmoles-per-m3-background

  ;Carboxylic acid parameters
  carboxyl-diffusion-dist
  carboxyl-lambda
  carboxyl-csat
  carboxyl-detection-limit

  ;Counting parameters
  total-trapped
  nb-mosquitos-leaving
  killed-by-human-quantity
  killed-by-nature-quantity

  ;Heat map of chemicals
  color1
  color2
  color3
  color4
  level1
  level2
  level3
  level4
]

;----------------------------------------------------------------;
;--------------------------------PHYSICAL CONSTANTS FROM LITERATURE--------------------------------;
;----------------------------------------------------------------;
;ARTICLE LISTING TYPES OF CARBOXYLIC ACIDS HUMANS RELEASE AND THAT ATTRACT MOSQUITOS:
;https://journals.plos.org/plosntds/article?id=10.1371/journal.pntd.0011402

;https://acp.copernicus.org/articles/23/6863/2023/
;Axelaic acid saturation partial pressure 7.61 * 10^-6 Pa

;https://www.researchgate.net/post/How_much_CO2_does_an_average_person_emit_by_breathing

;----------------------------------------------------------------;
;--------------------------------SETUP--------------------------------;
;----------------------------------------------------------------;
to setup
  clear-all
  reset-ticks ;necessary to allow updates during setup regardless of view update mode
  set setup-finished false

  ;Create a wind angle object
  create-wind-vanes 1
  [
    set heading wind-orientation
    set size 5
    set color blue
    set shape "arrow 3"
    setxy (max-pxcor - 3) (max-pycor - 3)
  ]

  ;General parameters
  set background-color green
  set chemical-steps-per-minute chemical-steps-per-tick * ticks-per-minute ; the chemical can be produced more frequently than the turtles are moved
  set air-pressure 101325 ;in Pascals
  set humans-per-house 3
  set house-list []
  set calibration-mosquito-count 0 ; initialize
  set calibration-avg-population 0 ; initialize
  set calibration-start-tick 200 ; tick after which the mosquito count is added to previous mosquito counts -> used to calculate the average population over hundreds of ticks

  ;Distance, Size and Volume parameters
  set scale meters-per-patch ;a distance of 1 in the model is equal to this value in meters
  set radius-for-chem-concentration 6 / scale ;in meters adjusted to the scale of a patch.
  if radius-for-chem-concentration < 1 [set radius-for-chem-concentration 1]; If the radius is smaller than the width of the patch, then correct it to the size of the patch
  set patch-height 2; in meters
  set patch-volume ((patch-size * scale) ^ 2 * patch-height) ;in m3
  set human-max-dist-from-house 12 / scale ; meters adjusted to map scale
  set human-min-dist-from-house 6 / scale ; meters adjusted to map scale

  ;Wind settings
  set prev-scale-parameter scale-parameter
  set prev-shape-parameter shape-parameter

  ;Mosquito specific parameters
  set bite-distance 8 / scale
  set vmin-mosquito 1 ; meters/min (minimum mosquito speed)
  set vmax-mosquito 15 ; meters/min (maximum mosquito speed)
  set trapping-rate 0.8 ;per minute 0 is none, 1 is always trapping
  set trapping-distance 5 / scale ;max distance at which trapping happens, in meters
  set sensitivity-trapchem 1
  set sensitivity-co2 1
  set sensitivity-carboxyl 1
  set filling-per-bite-min 0.4 ;multiply by 100 gives percent that a mosquito fills up with blood at a minimum (possible to fill 100% also)
  set filling-per-bite-max 1.5 ;same as previous variable, but increasing this value increases chances for 100% filling on the first bite (anything over 100% is counted as 100%)
  set minutes-spent-in-post-meal 10
  set fraction-spawned-at-border 0.95 ;spawn at border + up to max flight speed (random draw). The rest is spawned anywhere on the map

  ;General chemical parameters
  set millimoles-per-patch (patch-volume * 1000 / 22.414) * 1000 ; m3 * L/m3 ÷ (L/mol for gasses at atm pressure) * 1000 mmol/mol
  set chemical-diffusion-dist 0 ; initialize (in m/min)

  ;Trap chemical parameters
  set trapchem-diffusion-dist 0.331 / scale ;in m/min
  set trap-lambda 0.2 ;units of 1/min
  set trapchem-csat (0.00000764 / air-pressure * millimoles-per-patch / patch-volume) ; (Partial pressure saturated conc / Total pressure) * millimoles-per-patch ÷ mL/mmol of chem x 1000 L/mL -> units of mmol / L
  set trapchem-detection-limit trapchem-parts-per-trillion * (10 ^ -12) * (millimoles-per-patch / patch-volume) ; parts per trillion converted to mmoles/m3

  ;CO2 parameters
  set co2-diffusion-dist 0.635 / scale ;in m/min
  set co2-detection-limit-delta 5 * 10 ^ (-2); in mmoles/m3, increase compared to background co2 concentration
  set co2-mmoles-background (millimoles-per-patch * 0.0004) ;air is composed of 0.04% CO2
  set co2-mmoles-per-m3-background (co2-mmoles-background / patch-volume) ;in mmol/m3

  ;Carboxylic acid parameters
  set carboxyl-diffusion-dist 0.331 / scale ;in m/min
  set carboxyl-lambda 0.2
  set carboxyl-csat (0.00000764 / air-pressure * millimoles-per-patch / patch-volume) ; (Partial pressure saturated conc / Total pressure) * millimoles-per-patch ÷ mL/mmol of chem x 1000 L/mL -> units of mmol / L
  set carboxyl-detection-limit carboxylic-acid-parts-per-trillion * (10 ^ -12) * (millimoles-per-patch / patch-volume) ; parts per trillion converted to mmoles/m3

  ;Counting parameters
  set total-trapped 0
  set nb-mosquitos-leaving 0
  set killed-by-human-quantity 0
  set killed-by-nature-quantity 0

  ;Functions to generate turtles, patches and wind parameters
  setup-patches
  setup-decor
  if calibration = False
  [
    setup-traps
    setup-houses
    setup-humans
  setup-mosquitos
  ]
  wind-speed-distribution

  reset-ticks ;now reset because the previous ticks were only for setup
  set setup-finished true
end

;----------------------------------------------------------------;
;--------------------------------GO--------------------------------;
;----------------------------------------------------------------;
to go
  ;Parameters to be reinitialized to allow for live adjustments
  set human-killing-proficiency human-kill-mosquito-chance-per-hour / 60 / ticks-per-minute ;multiply by 100 -> % chance to kill a meal-seeking mosquito in biting range (per tick)
  set natural-death-rate mosquito-natural-death-chance-per-hour / 100 / 60 / ticks-per-minute; multiply by 100 -> %chance a mosquito is killed by its environnement every tick (spiders, etc.)

  ;Check to see if the wind parameters are changed in the middle of the simulation and update if it is the case
  if ((prev-scale-parameter != scale-parameter) or (prev-shape-parameter != shape-parameter))
  [
    wind-speed-distribution
    set prev-scale-parameter scale-parameter
    set prev-shape-parameter shape-parameter
  ]
  ;allow dynamic modification of wind speed by placing this calculation in the go step
  set wind-speed one-of speed-samples

  ;update the indicator for the wind orientation
  ask wind-vanes [set heading wind-orientation]
  ;Calibration allows to examine mosquito movements and determine the correct spawning rate for the given starting number of mosquitos
  ifelse calibration = True
  [
    move-mosquitos
    natural-death
    spawn-mosquitos-center
    spawn-mosquitos-border
  ]
  [
    ;the chemical loops need to run several times before the animals
    let i 0
    while [i < chemical-steps-per-tick]
    [
      ;if the chemicals are frozen, then they don't need to be updated. Otherwise, update them.
      if freeze-chemicals = false
      [
        move-chemicals
        make-trapchem
        make-human-chems
        get-chem-per-patch
      ]
      set i (i + 1)
    ]
    set-patch-colors
    natural-death
    move-mosquitos
    spawn-mosquitos-center
    spawn-mosquitos-border
    bite
    kill-by-humans
    trap-mosquitos
    lifecycle-mosquitos
    count-trapped
  ]
  if (calibration = True) and (ticks > calibration-start-tick)
  [
    set calibration-mosquito-count calibration-mosquito-count + count tiger-mosquitos
    set calibration-avg-population calibration-mosquito-count / (ticks - calibration-start-tick)
  ]
  tick
  ;if (ticks > 1000) [stop]
end

;----------------------------------------------------------------;
;--------------------------------SETUP SUB-FUNCTIONS--------------------------------;
;----------------------------------------------------------------;
to setup-patches
  ask patches
  [
    set pcolor background-color
    set ptrapchem-mmoles-per-m3 0
    set pco2-mmoles-per-m3 co2-mmoles-per-m3-background
    set pcarboxyl-mmoles-per-m3 0
  ]
  wait 0.1 ;without a small wait, the graphical update is not complete
  tick ;allows immediate grapical update regardless of view update mode
end

to setup-decor
  create-decors 120
  [
    set shape "plant"
    set color [120 255 120]
    set size 15 / patch-size
    setxy random-xcor random-ycor
  ]
  wait 0.1 ;without a small wait, the graphical update is not complete
  tick ;allows immediate grapical update regardless of view update mode
end


to setup-traps
  ;count the number of traps place
  ;if the mouse cursor is inside the map, allow a trap placement
  ;a delay is required to prevent traps being placed all at once
  output-print "--> PLACE TRAPS NOW..."
  let num-placed 0
  while [num-placed < num-traps]
  [if (mouse-inside? = true) and (mouse-down? = true)
     [create-traps 1
       [set shape "target"
        set color red
        set size 15 / patch-size
        set trapchem-release-rate trap-lambda ;in millimoles/min
        set num-trapped 0
        setxy mouse-xcor mouse-ycor]
       set num-placed (num-placed + 1)
       output-print "Trap placed"
      wait 0.1 ;without a small wait, the graphical update is not complete
      tick ;allows immediate grapical update regardless of view update mode
      wait 0.2
     ]
    ]
  output-print "... finished placing traps."
  output-print ""
end

to setup-houses
  ;count the number of houses placed
  ;if the mouse cursor is inside the map, allow a house placement as long as restrictions are met
  ;a delay is required to prevent traps being placed all at once

  output-print "--> PLACE HOUSES NOW..."
  let num-placed 0
  while [num-placed < num-houses]
  [if (mouse-inside? = true) and (mouse-down? = true)
    [
      ;retrieve mouse click position
      let xpos mouse-xcor
      let ypos mouse-ycor
      let close-edge False
      ;let close-other false

      ;Check that position is valid
      let xleft (xpos - human-max-dist-from-house / 2)
      let xright (xpos + human-max-dist-from-house / 2)
      let ydown (ypos - human-max-dist-from-house / 2)
      let yup (ypos + human-max-dist-from-house / 2)
      if (xleft < min-pxcor) or (xright > max-pxcor) or (ydown < min-pycor) or (yup > max-pycor)
      [set close-edge True]

      ifelse close-edge = True
      [
        ;output an error message if too close to map edge. The counter is not updated in this case.
        output-print "ERROR: House too close to edge!"
      ]
      [
        create-properties 1
        [
          set shape "fence-perimeter"
          setxy xpos ypos
          set color brown
          set size (human-max-dist-from-house * 2)
        ]

        create-houses 1
        [
          set shape "house"
          set color white
          set size 20 / patch-size
          setxy xpos ypos
          set label word "HOUSE" (num-placed + 1)
          set label-color red
          set house-list lput who house-list
        ]

        ;update counter and print message saying a house was placed
        set num-placed (num-placed + 1)
        output-print "House placed."
      ]
      tick ;allows immediate grapical update regardless of view update mode
      wait 0.2
    ]
  ]
  output-print "... finished placing houses."
  output-print ""
end

to setup-humans
  if num-houses > 0
  [
    ask houses
    [
      hatch-humans humans-per-house
      [
        create-link-from myself
        set color yellow
        set shape "person"
        set size 14 / patch-size
        set nb-of-bites 0
        set co2-prod 14.3 ;mmol/min
        set carboxylic-prod 4.5
        setxy [xcor] of myself [ycor] of myself
        set heading random 360
        set label ""
      ]
    ]
    ask humans
    [
      forward (random-float (human-max-dist-from-house  - human-min-dist-from-house)) + human-min-dist-from-house
    ]
  ]
end


;----------------------------------------------------------------;
;--------------------------------MOSQUITO GENERATION FUNCTIONS--------------------------------;
;----------------------------------------------------------------;
;Make mosquitos at setup and spawn new ones during the simulation
to setup-mosquitos
  ;Create the mosquitos
  create-tiger-mosquitos num-tiger-mosquitos
  [
    set xcor random-xcor
    set ycor random-ycor
    set color red
    set size 10 / patch-size
    set bite-probability 0.2 ;multiply by 100 and this gives the percent chance of making a bite each minute
    set sex "female"
    set lifecycle-stage "meal-seeking"
    ;set sex one-of ["female" "male"]
    ;ifelse sex = "male"
    ;[set lifecycle-stage "maturation-breeding"]
    ;[set lifecycle-stage one-of ["maturation-breeding" "meal-seeking" "post-meal" "gravid"]]
  ]
end

to spawn-mosquitos-center
  create-tiger-mosquitos mosquito-spawn-per-minute / ticks-per-minute * (1 - fraction-spawned-at-border) ;mosquitos per minute, fraction not at border
  [
    set color red
    set size 10 / patch-size
    set bite-probability 0.2 ;multiply by 100 and this gives the percent chance of making a bite each minute
    set sex "female"
    set lifecycle-stage "meal-seeking"
    setxy random-xcor random-ycor
  ]
  spawn-mosquitos-border
end

to spawn-mosquitos-border
  let mosquito-rate-one-border mosquito-spawn-per-minute / ticks-per-minute * fraction-spawned-at-border / 4 ;mosquitos per minute, fraction at each border
  let fixed-mosquito-generation floor (mosquito-rate-one-border) ;this is the integer part of the generation rate (always create this number of mosquitos)
  let statistical-mosquito-generation (mosquito-rate-one-border - fixed-mosquito-generation) ;this is the decimal part of the generation rate (a roll of the die decides if it is created)
  let random-roll random-float 1 ;a roll of the die
  let num-to-create fixed-mosquito-generation ;set the base rate of mosquito generation before adding the random part
  if random-roll < statistical-mosquito-generation [set num-to-create num-to-create + 1] ;if the die roll is less than the decimal part, then we are within the probability and an extra mosquito is generated

  ;Create mosquitos at each border, up to a distance representing half of its max speed
  if num-to-create >= 1
  [
    create-tiger-mosquitos num-to-create
    [
      let border one-of [-1 1 -2 2]

      ;left vertical border
      if border = -1
      [
        set ycor random-ycor ;anywhere along the border
        set heading 90 ; perpendicular to the border
        let dist-from-border random-float (vmax-mosquito) / scale / ticks-per-minute ;the mosquito, due to its flight speed doesn't necessarily appear a the border, but a certain distance past the border (up to half v-max)
        ;verify that the distance is valid (otherwise it creates a critical error)
        ifelse dist-from-border < max-pxcor
          [set xcor 0 + dist-from-border]
          [set xcor 0] ; if it fails, just put the mosquito directly at the border]
        set ycor random max-pycor ;any value on the vertical
      ]
      ;right vertical border
      if border = 1
      [
        set ycor random-ycor ;anywhere along the border
        set heading 270 ; perpendicular to the border
        let dist-from-border random-float (vmax-mosquito) / scale / ticks-per-minute ;the mosquito, due to its flight speed doesn't necessarily appear a the border, but a certain distance past the border (up to half v-max)
        ;verify that the distance is valid (otherwise it creates a critical error)
        ifelse dist-from-border < max-pxcor
          [set xcor max-pxcor - dist-from-border]
          [set xcor max-pxcor] ; if it fails, just put the mosquito directly at the border]
        set ycor random max-pycor ;any value on the vertical
      ]
      ;bottom horizontal border
      if border = -2
      [
        set ycor random-ycor ;anywhere along the border
        set heading 0 ; perpendicular to the border
        let dist-from-border random-float (vmax-mosquito) / scale / ticks-per-minute ;the mosquito, due to its flight speed doesn't necessarily appear a the border, but a certain distance past the border (up to half v-max)
        ;verify that the distance is valid (otherwise it creates a critical error)
        ifelse dist-from-border < max-pycor
          [set ycor 0 + dist-from-border]
          [set ycor 0] ; if it fails, just put the mosquito directly at the border]
        set xcor random max-pxcor ;any value on the vertical
      ]
      ;upper horizontal border
      if border = 2
      [
        set ycor random-ycor ;anywhere along the border
        set heading 180 ; perpendicular to the border
        let dist-from-border random-float (vmax-mosquito) / scale / ticks-per-minute ;the mosquito, due to its flight speed doesn't necessarily appear a the border, but a certain distance past the border (up to half v-max)
        ;verify that the distance is valid (otherwise it creates a critical error)
        ifelse dist-from-border < max-pycor
          [set ycor max-pycor - dist-from-border]
          [set ycor max-pycor] ; if it fails, just put the mosquito directly at the border
        set xcor random max-pxcor ;any value on the vertical
      ]

      set color red
      set size 10 / patch-size
      set bite-probability 0.2 ;multiply by 100 and this gives the percent chance of making a bite each minute
      set sex "female"
      set lifecycle-stage "meal-seeking"
      ;set sex one-of ["female" "male"]
      ;ifelse sex = "male"
      ;[set lifecycle-stage "maturation-breeding"]
      ;[set lifecycle-stage one-of ["maturation-breeding" "meal-seeking" "post-meal" "gravid"]]
    ]
  ]
end


;----------------------------------------------------------------;
;--------------------------------MOVE FUNCTIONS--------------------------------;
;----------------------------------------------------------------;
to move-mosquitos
  let following-chem-rotate 10 ;randomness in orientation when the mosquito is following a chemical gradient
  ;mosquitos will move only if the wind is slower than their maxiumum speed
  if wind-speed < vmax-mosquito
  [
    ask tiger-mosquitos [
      let angle-desired heading ;initialize desired orientation
      let v-desired 0 ;initialize speed
      ;Retrieve the concentrations of chemicals in the patch where the agent is loctated
      let trapchem-mmoles-per-m3 [ptrapchem-mmoles-per-m3] of patch-here
      let co2-mmoles-per-m3 [pco2-mmoles-per-m3] of patch-here
      let carboxyl-mmoles-per-m3 [pcarboxyl-mmoles-per-m3] of patch-here

      ;Check that to see if each chemical is at the detection limit or higher (only if in meal-seeking stage)
      ifelse lifecycle-stage = "meal-seeking"
      [
        ifelse trapchem-mmoles-per-m3 >= trapchem-detection-limit [set trapchem-on 1] [set trapchem-on 0]
        ifelse (co2-mmoles-per-m3 - co2-mmoles-per-m3-background) >= co2-detection-limit-delta [set co2-on 1] [set co2-on 0]
        ifelse carboxyl-mmoles-per-m3 >= carboxyl-detection-limit [set carboxyl-on 1] [set carboxyl-on 0]
      ]
      [
        set trapchem-on 0
        set co2-on 0
        set carboxyl-on 0
      ]
      ;if at least one chemical is at the detection limit, then find the path
      set choice-of-direction "none"
      ifelse (trapchem-on + co2-on + carboxyl-on) > 0
      [
        ;Retrieve the gradient magnitude of the chemicals in the patch where the agent is located
        let gradient-magnitude-trapchem [pgradient-magnitude-trapchem] of patch-here
        let gradient-magnitude-co2 [pgradient-magnitude-co2] of patch-here
        let gradient-magnitude-carboxyl [pgradient-magnitude-carboxyl] of patch-here

        ;Retrieve the gradient orientation of the chemicals in the patch where the agent is located
        let gradient-orientation-trapchem [pgradient-orientation-trapchem] of patch-here
        let gradient-orientation-co2 [pgradient-orientation-co2] of patch-here
        let gradient-orientation-carboxyl [pgradient-orientation-carboxyl] of patch-here

        ;Calculate the response variable for each chemical by normalizing with respect to the detection limits (a zero from the code above deactivates the chemical in question)
        let trapchem-value trapchem-on * (sensitivity-trapchem * (trapchem-mmoles-per-m3 / trapchem-detection-limit) * (gradient-magnitude-trapchem / trapchem-detection-limit))
        let co2-value co2-on * (sensitivity-co2 * (co2-mmoles-per-m3 - co2-mmoles-per-m3-background) / co2-detection-limit-delta * (gradient-magnitude-co2 / co2-detection-limit-delta))
        let carboxyl-value carboxyl-on * (sensitivity-carboxyl * (carboxyl-mmoles-per-m3 / carboxyl-detection-limit) * (gradient-magnitude-carboxyl / carboxyl-detection-limit))

        ;Determine which chemical gives the highest response variable
        ifelse (trapchem-value >= co2-value) and (trapchem-value >= carboxyl-value) [set choice-of-direction "trap chemical"]
        [ifelse (co2-value >= trapchem-value) and (co2-value >= carboxyl-value) [set choice-of-direction "co2"]
          [set choice-of-direction "carboxylic acids"]]

        ifelse choice-of-direction = "trap chemical" [set heading gradient-orientation-trapchem]
        [ifelse choice-of-direction = "co2" [set heading gradient-orientation-co2]
          [set heading gradient-orientation-carboxyl]]
        set angle-desired (heading - 1 * following-chem-rotate / 2 + random following-chem-rotate)
        set v-desired random-float (vmin-mosquito + (vmax-mosquito - vmin-mosquito)) ; speed is any value from its min to its max speed
      ]
      [
        ;only meal seeking mosquitos follow chemical paths, so post-meal and gravid mosquitos move differently
        ifelse lifecycle-stage = "post-meal"
        [
          set angle-desired (heading - 40 + random 80) ;directional, to move a bit away from the last host
          set v-desired random-float (vmin-mosquito + (vmax-mosquito - vmin-mosquito)) ; speed is any value from its min to its max speed
        ]
        [if lifecycle-stage != "gravid"
          [

            set angle-desired random 360 ;totally random
            set v-desired random-float (vmin-mosquito + (vmax-mosquito - vmin-mosquito)) ; speed is any value from its min to its max speed
          ]
        ]
      ]

      ;to prevent bias in movement, the equivalent maximum speed when moving generally going in the same direction as the wind must be calculated. If the mosquito is going in the direction of the wind, we reverse its direction.
      ;this means that regardless of movement direction, the mosquito will not have an average direction biased with the wind.
      let inversed? 0
      if (wind-orientation - angle-desired > -90) and (wind-orientation - angle-desired < 90)
      [
        set angle-desired -1 * angle-desired
        set inversed? 1
      ]

      ;These trigonometric formulas determine the adjusted angle and needed speed to reach the destination
      let angle-desired-wrt-wind 90 - (wind-orientation - angle-desired)
      let vx-desired (v-desired * sin(angle-desired-wrt-wind))
      let vy-desired (v-desired * cos(angle-desired-wrt-wind))
      let vx-wind-adj vx-desired - wind-speed

      let v-real v-desired ;initialize at desired speed
                           ;adjust speed if the wind will not allow it
      if sqrt(vx-wind-adj ^ 2 + vy-desired ^ 2) > vmax-mosquito
      [
        ;if the mosquito can't meet it's desired destination, then it must use the correct angle to counter the wind and go as far as its vmax allows
        let angle-wind-adj (atan vx-wind-adj vy-desired)
        let vx-possible vmax-mosquito * sin(angle-wind-adj)
        let vy-possible vmax-mosquito * cos(angle-wind-adj)

        ifelse sin(angle-desired) != 0
        [set v-real vx-possible / sin(angle-desired)]
        [set v-real vy-possible]
      ]

      ;If the angle was reversed to prevent wind bias, correct it
      if inversed? = 1 [set angle-desired -1 * angle-desired]

      ;Move the mosquito the calculated distance at the desired angles
      set heading angle-desired
      if v-real < 0 [set v-real 0]
      if can-move? (v-real / scale) = False
      [
        set nb-mosquitos-leaving nb-mosquitos-leaving + 1
        die
      ]
      forward v-real / scale / ticks-per-minute ;they a moved with the chemicals (several times per tick)
    ]
  ]
end

;if it is desired to add humans that roam, then a new parameter must be created for the humans (roaming?). This will distiguish the house humans from the roaming.
;to move-humans
;  if roaming? = True
;  [
;    ask humans [forward 2 / scale / ticks-per-minute right (random 90) - 45]
;  ]
;end

to move-chemicals
  ;dissappearing of chemicals via diffusion up... 5 directions possible (west, east, south, north, up). One out of 5 chem-transporters must be removed.
  let kill-number round(percent-chem-loss / 100 * (count chem-transporters))
  ask n-of kill-number chem-transporters [die]
  ask chem-transporters [
    ;Set the appropriate diffusion speed according to the molecule in the chem-transporter
    if trapchem-mmoles > 0 [set chemical-diffusion-dist trapchem-diffusion-dist]
    if co2-mmoles > 0 [set chemical-diffusion-dist co2-diffusion-dist]
    if carboxyl-mmoles > 0 [set chemical-diffusion-dist carboxyl-diffusion-dist]

    ;convection
    set heading (wind-orientation - (local-wind-orientation-variability / 2) + random-float local-wind-orientation-variability)
    forward wind-speed / scale / chemical-steps-per-minute

    ;diffusion
    right random 360
    forward chemical-diffusion-dist / chemical-steps-per-minute
    if xcor > max-pxcor [die]
    if xcor < min-pxcor [die]
    if ycor > max-pycor [die]
    if ycor < min-pycor [die]
    set nb-moves nb-moves + 1

    let num-generated 2
    if nb-moves >= 15 [
      hatch num-generated
      [
        set nb-moves 0
        set trapchem-mmoles trapchem-mmoles / num-generated
      ]
      die
    ]
  ]
end
;----------------------------------------------------------------;
;--------------------------------MOSQUITO FUNCTIONS--------------------------------;
;----------------------------------------------------------------;
to trap-mosquitos
  let radius trapping-distance
  ask tiger-mosquitos
  [
    if any? traps in-radius radius
    [
      let luck random-float 1
      if luck < trapping-rate / ticks-per-minute; per tick, so adjustment needed
      [
        ask one-of traps in-radius radius
        [

          set num-trapped num-trapped + 1
        ]
        die
      ]
    ]
  ]
end

to count-trapped
  set total-trapped sum([num-trapped] of traps)
end

to bite
  ask tiger-mosquitos
  [
    if lifecycle-stage = "meal-seeking"
    [
      let probability bite-probability
      let succeed 0
      if any? humans in-radius bite-distance
      [
        ask one-of humans in-radius bite-distance
        [let prob-roll random-float 1
          if prob-roll < probability / ticks-per-minute ;per tick, so adjustment needed
          [
            set nb-of-bites nb-of-bites + 1 ;add 1 to the count of bites received by the human
            set succeed 1
          ]
        ]
      ]
      if succeed = 1 [set nb-of-bites nb-of-bites + 1] ;add 1 to the count of bites made by the mosquito
      ;Each bite can fill up the mosquito a random amount, from a minimum value to maximum. This value must then be added to the fraction-full-of-blood variable
      if succeed = 1
      [
        let proba-fill (filling-per-bite-min + random-float (filling-per-bite-max - filling-per-bite-min)) ;the probabilities are calculated between 0 and the upper value, so an adjustment is necessary to allow for the desired min value
        set fraction-full-of-blood fraction-full-of-blood + proba-fill
        if fraction-full-of-blood > 1
        [
          set fraction-full-of-blood 1
          set lifecycle-stage "post-meal"
          set minutes-in-lifecycle 0 ;reset the counter for the new stage
          set color black
        ]
      ]
    ]
  ]
end

to lifecycle-mosquitos
  ;!!!! see the "bite" function for transition from "meal-seeking" to "post-meal" !!!!
  ask tiger-mosquitos
  [
    set minutes-in-lifecycle minutes-in-lifecycle + (1 / ticks-per-minute)
    if (lifecycle-stage = "post-meal") and (minutes-in-lifecycle = minutes-spent-in-post-meal)
    [
      set lifecycle-stage "gravid"
      set color gray
      set minutes-in-lifecycle 0 ;reset the counter for the new stage
    ]
  ]
end

to kill-by-humans
  ;use the mosquito bite-distance to verify if it is attacking the human (moment it can be killed)
  ask humans [
    let proba-roll random-float 1
    if (proba-roll < human-killing-proficiency / ticks-per-minute) and (count tiger-mosquitos in-radius bite-distance > 0) ;per tick killing proficiency requires correction for ticks-per-minute
    [
      ask one-of tiger-mosquitos in-radius bite-distance [die]
      set killed-by-human-quantity killed-by-human-quantity + 1
    ]
  ]
end

to natural-death
  ask tiger-mosquitos
  [
    if random-float 1 < natural-death-rate / ticks-per-minute ;per tick, so corrected with ticks-per-minute
    [
      set killed-by-nature-quantity killed-by-nature-quantity + 1
      die
    ]
  ]
end

;----------------------------------------------------------------;
;--------------------------------TRAP CHEMICAL GENERATION, PATCH CONCENTRATION, AND COLOR SCHEME FUNCTIONS--------------------------------;
;----------------------------------------------------------------;
to make-trapchem
  ;get volume of diffusion zone
  let radius radius-for-chem-concentration ;diffusion radius in meters used to determine the local concentration
  let volume (3.14159 * (radius * scale) ^ 2 * patch-height) * 1000 ;in liters

  ;generate trapchem based on the concentration
  ask traps [
    let total-trapchem (sum [trapchem-mmoles] of chem-transporters in-radius radius) ; in mmol
    let concentration (total-trapchem / volume) ; in mmol/L
    let new-mmoles ((trap-lambda * (trapchem-csat - concentration)) * volume) / chemical-steps-per-minute ; 1/min * (mmol/L - mmol/L) * L
    if new-mmoles < 0 [set new-mmoles 0] ;make sure the traps don't reabsorb the chemical!

    ;now hatch new chemicals
    let num-generated 120
    let num-transporters num-generated
    hatch-chem-transporters num-transporters
    [
      set hidden? true
      set color red
      set size 2
      set nb-moves 0
      set trapchem-mmoles new-mmoles / num-generated
      right random 360
      forward (random 201) / 100 * trapchem-diffusion-dist / chemical-steps-per-minute ;the first diffusion is between 0 and 2x the mean diffusion distance
    ]
  ]
end

to make-human-chems
  ;get volume of diffusion zone
  let radius radius-for-chem-concentration ;diffusion radius used to determine the local concentration
  let volume (3.14159 * (radius * scale) ^ 2 * patch-height) * 1000 ;in liters

  ;generate co2 and carboxylic acids based on the concentration
  ask humans [
    ;CO2 generation
    let new-mmoles co2-prod / chemical-steps-per-minute ; mmol/min divided by number of steps per tick
    if new-mmoles < 0 [set new-mmoles 0] ;make sure the traps don't reabsorb the chemical!
    ;now hatch new co2
    let num-generated 120
    let num-transporters num-generated
    hatch-chem-transporters num-transporters
    [
      set hidden? true
      set color red
      set size 2
      set nb-moves 0
      set co2-mmoles new-mmoles / num-generated
      right random 360
      forward (random 201) / 100 * co2-diffusion-dist / chemical-steps-per-minute ;the first diffusion is between 0 and 2x the mean diffusion distance
    ]

    ;Carboxylic acids generation
    let total-carboxyl (sum [carboxyl-mmoles] of chem-transporters in-radius radius) ; in mmol
    let concentration (total-carboxyl / volume) ; in mmol/L
    set new-mmoles ((carboxyl-lambda * (carboxyl-csat - concentration)) * volume) / chemical-steps-per-minute ; 1/min * (mmol/L - mmol/L) * L
    if new-mmoles < 0 [set new-mmoles 0] ;make sure the traps don't reabsorb the chemical!
    ;now hatch new carboxylic acids
    set num-generated 120
    set num-transporters num-generated
    hatch-chem-transporters num-transporters
    [
      set hidden? true
      set color red
      set size 2
      set nb-moves 0
      set carboxyl-mmoles new-mmoles / num-generated
      right random 360
      forward (random 201) / 100 * carboxyl-diffusion-dist / chemical-steps-per-minute ;the first diffusion is between 0 and 2x the mean diffusion distance
    ]
  ]
end

to get-chem-per-patch
  let radius radius-for-chem-concentration ;radius in which to search for chem-transporters and calculate the average concentration
  ask patches [
    set ptrapchem-mmoles-per-m3 (sum [trapchem-mmoles] of chem-transporters in-radius radius) / (pi * ((radius * scale) ^ 2) * patch-height) ;in millimoles/m3
    set pco2-mmoles-per-m3 co2-mmoles-per-m3-background + (sum [co2-mmoles] of chem-transporters in-radius radius) / (pi * ((radius * scale) ^ 2) * patch-height) ;in millimoles/m3
    set pcarboxyl-mmoles-per-m3 (sum [carboxyl-mmoles] of chem-transporters in-radius radius) / (pi * ((radius * scale) ^ 2) * patch-height) ;in millimoles/m3
  ]
  ask patches
  [
    let this-patch-xcor pxcor
    let this-patch-ycor pycor

    ;---TRAPCHEM GRADIENT CALCULATION---
    let x-gradient-direction (sum [(pxcor - this-patch-xcor) * ptrapchem-mmoles-per-m3] of neighbors)
    let y-gradient-direction (sum [(pycor - this-patch-ycor) * ptrapchem-mmoles-per-m3] of neighbors)
    if x-gradient-direction != 0
    [
      set pgradient-orientation-trapchem (atan x-gradient-direction y-gradient-direction)
      set pgradient-magnitude-trapchem abs (ptrapchem-mmoles-per-m3 - ([ptrapchem-mmoles-per-m3] of patch-at-heading-and-distance pgradient-orientation-trapchem 1))
    ]

    ;---CO2 GRADIENT CALCULATION---
    set x-gradient-direction (sum [(pxcor - this-patch-xcor) * pco2-mmoles-per-m3] of neighbors)
    set y-gradient-direction (sum [(pycor - this-patch-ycor) * pco2-mmoles-per-m3] of neighbors)
    if x-gradient-direction != 0
    [
      set pgradient-orientation-co2 (atan x-gradient-direction y-gradient-direction)
      set pgradient-magnitude-co2 abs (pco2-mmoles-per-m3 - ([pco2-mmoles-per-m3] of patch-at-heading-and-distance pgradient-orientation-co2 1))
    ]

    ;---CARBOXYLIC ACIDS GRADIENT CALCULATION---
    set x-gradient-direction (sum [(pxcor - this-patch-xcor) * pcarboxyl-mmoles-per-m3] of neighbors)
    set y-gradient-direction (sum [(pycor - this-patch-ycor) * pcarboxyl-mmoles-per-m3] of neighbors)
    if x-gradient-direction != 0
    [
      set pgradient-orientation-carboxyl (atan x-gradient-direction y-gradient-direction)
      set pgradient-magnitude-carboxyl abs (pcarboxyl-mmoles-per-m3 - ([pcarboxyl-mmoles-per-m3] of patch-at-heading-and-distance pgradient-orientation-carboxyl 1))
    ]
  ]
end

to set-patch-colors
  ;---TRAPCHEM COLOR SETTINGS---
  if heatmap-choice = "trapchem"
  [
    set color1 [235 0 150]
    set color2 [255 102 200]
    set color3 [255 191 200]
    set color4 [255 235 200]

    set level1 150 * trapchem-detection-limit ; in mmoles/m3
    set level2 50 * trapchem-detection-limit ; in mmoles/m3
    set level3 10 * trapchem-detection-limit ; in mmoles/m3
    set level4 trapchem-detection-limit ; in mmoles/m3
  ]
  ;---CO2 COLOR SETTINGS---
  if heatmap-choice = "co2"
  [
    set color1 [0 50 200]
    set color2 [0 102 200]
    set color3 [0 191 200]
    set color4 [0 255 200]

    set level1 10 * co2-detection-limit-delta + co2-mmoles-per-m3-background ; in mmoles/m3
    set level2 5 * co2-detection-limit-delta + co2-mmoles-per-m3-background ; in mmoles/m3
    set level3 2 * co2-detection-limit-delta + co2-mmoles-per-m3-background ; in mmoles/m3
    set level4 co2-detection-limit-delta + co2-mmoles-per-m3-background ; in mmoles/m3
  ]
  ;---CARBOXYLIC ACIDS COLOR SETTINGS---
  if heatmap-choice = "carboxylic-acids"
  [
    set color1 [225 85 10]
    set color2 [255 135 40]
    set color3 [255 185 100]
    set color4 [255 255 130]

    set level1 150 * carboxyl-detection-limit ; in mmoles/m3
    set level2 50 * carboxyl-detection-limit ; in mmoles/m3
    set level3 10 * carboxyl-detection-limit ; in mmoles/m3
    set level4 carboxyl-detection-limit ; in mmoles/m3
  ]

  ask patches
  [
    let concentration 0
    if heatmap-choice = "trapchem"
    [set concentration ptrapchem-mmoles-per-m3] ;in mmoles/m3

    if heatmap-choice = "co2"
    [set concentration pco2-mmoles-per-m3] ;in mmoles/m3

    if heatmap-choice = "carboxylic-acids"
    [set concentration pcarboxyl-mmoles-per-m3] ;in mmoles/m3

    ifelse heatmap-choice = "none"
    [
      set pcolor background-color
    ]
    [
      ifelse concentration >= level1 [set pcolor color1]
      [ifelse concentration >= level2 [set pcolor color2]
        [ifelse concentration >= level3 [set pcolor color3]
          [ifelse concentration >= level4 [set pcolor color4]
            [set pcolor background-color]
        ]]]]
  ]
end


;Take a volume around each trap, see how many chem-transporters are there and sum their trapchem quantities.
;This determines how much trapchem to create (Dalton's law)
;Call the function that makes transporters for trapchem
;Move these transporters to a random place within the volume (the orientation is set during creation, but the movement is done after)

;----------------------------------------------------------------;
;--------------------------------WIND SPEED AND ORIENTATION FUNCTIONS--------------------------------;
;----------------------------------------------------------------;
to wind-speed-distribution
  let maxv (scale-parameter * 3) ; this is the maximum speed allowed. Based on the Weibull distribution equation, taking 3x the scale parameter is good (we don't really want extreme events in this simulation
  let numsteps 100 ; defines the number of points to calculate in the Weibull distribution
  let prob-multiplier 10000 ;convert probabilities to number of occurrences... the objective is to have 1 occurrence for the least likely speed in the distribution
  let speed-step (maxv / numsteps) ;the speed change between two steps
  let v 0 ;this is a speed that will be adjusted within the functio
  let probfunc 0 ;initialize the Weibull distribution
  ;let prob 0; initialize the temporary prob
  let nb-samples 0 ;initialize the number of samples to place in a list
  set speed-samples [0] ;this list will hold the distribution of speeds. The most probably speed may have hundreds of occurrences while the least probable should only have 1

  let i 0 ;iterator for calculating a step in the Weibull distribution
  let j 0 ;iterator for the generation of speed samples added to the speed-samples list according to the calculated probability
  while [i < numsteps]
  [ifelse scale-parameter > 0
    [
      set v (speed-step * i)
      set probfunc ( shape-parameter / scale-parameter ) * (( v / scale-parameter ) ^ ( shape-parameter - 1 )) * (e ^ (-1 * ( v / scale-parameter ) ^ shape-parameter ))
      set nb-samples (round (probfunc * speed-step * prob-multiplier))]
    [
      set v 0
      set nb-samples 1
    ]
    set j 0
    while [j < nb-samples]
    [
      set speed-samples lput v speed-samples
      set j ( j + 1 )
    ]
    set i (i + 1)
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
435
11
1516
1093
-1
-1
10.624
1
10
1
1
1
0
0
0
1
0
100
0
100
1
1
1
ticks
30.0

BUTTON
269
209
333
242
Setup
set calibration false\nset freeze-chemicals false\nsetup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
340
209
403
242
Go
set calibration false\ngo
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

CHOOSER
18
269
110
314
num-traps
num-traps
0 1 2 3
1

CHOOSER
120
269
212
314
num-houses
num-houses
0 1 2 3 4 5 6
1

OUTPUT
15
12
409
180
11

SLIDER
18
358
190
391
num-tiger-mosquitos
num-tiger-mosquitos
0
2500
440.0
1
1
NIL
HORIZONTAL

MONITOR
13
890
254
935
Total number of hidden chemical transporters
count chem-transporters
0
1
11

SLIDER
1542
458
1714
491
wind-orientation
wind-orientation
0
359
53.0
1
1
NIL
HORIZONTAL

INPUTBOX
1732
456
1907
516
local-wind-orientation-variability
30.0
1
0
Number

SLIDER
1539
372
1712
405
scale-parameter
scale-parameter
0
18
8.45
0.05
1
m/s
HORIZONTAL

SLIDER
1733
372
1905
405
shape-parameter
shape-parameter
1
4
1.8
0.1
1
NIL
HORIZONTAL

PLOT
1539
11
1894
275
Wind speed distribution
Wind speed (m/s)
Frequency (10 000 samples)
0.0
50.0
0.0
10.0
true
false
"set-histogram-num-bars 100" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram speed-samples"

TEXTBOX
1543
342
1734
365
Wind speed parameters\n
16
0.0
1

MONITOR
1539
282
1682
327
Mean wind speed (km/h)
mean speed-samples * 60 * 60 / 1000
2
1
11

SLIDER
14
723
203
756
percent-chem-loss
percent-chem-loss
10
20
16.0
0.5
1
%
HORIZONTAL

MONITOR
218
942
385
987
Total nb of trapped mosquitos
total-trapped
0
1
11

CHOOSER
227
270
366
315
heatmap-choice
heatmap-choice
"none" "trapchem" "co2" "carboxylic-acids"
1

SLIDER
13
481
300
514
human-kill-mosquito-chance-per-hour
human-kill-mosquito-chance-per-hour
0
10
4.0
0.5
1
%
HORIZONTAL

SLIDER
13
528
299
561
mosquito-natural-death-chance-per-hour
mosquito-natural-death-chance-per-hour
0
5
0.5
0.1
1
%
HORIZONTAL

TEXTBOX
14
447
250
487
Mosquito death parameters
16
124.0
1

TEXTBOX
15
325
229
345
Mosquito spawning
16
124.0
1

TEXTBOX
16
691
166
711
Chemical parameters
16
0.0
1

MONITOR
13
942
179
987
Total number of mosquitos
count tiger-mosquitos
17
1
11

MONITOR
218
993
318
1038
Killed by humans
killed-by-human-quantity
17
1
11

MONITOR
218
1045
320
1090
Killed by nature
killed-by-nature-quantity
17
1
11

CHOOSER
17
209
155
254
meters-per-patch
meters-per-patch
1 2 5
1

PLOT
1538
864
1932
1092
Total number of mosquitos
Ticks
Number of mosquitos
0.0
10.0
0.0
10.0
true
false
"set setup-finished false" ""
PENS
"Total" 1.0 0 -16777216 true "" "if setup-finished = true [plot count tiger-mosquitos]"

SLIDER
17
399
291
432
mosquito-spawn-per-minute
mosquito-spawn-per-minute
0
200
100.0
1
1
NIL
HORIZONTAL

INPUTBOX
13
613
127
673
sensitivity-trapchem
1.0
1
0
Number

INPUTBOX
145
613
232
673
sensitivity-co2
1.0
1
0
Number

INPUTBOX
250
612
364
672
sensitivity-carboxyl
1.0
1
0
Number

TEXTBOX
14
582
323
603
Mosquito relative sensitivities to chemicals
16
124.0
1

TEXTBOX
1544
425
1750
448
Wind orientation parameters
16
0.0
1

MONITOR
1753
282
1895
327
Mean wind speed (m/s)
mean speed-samples
2
1
11

PLOT
1538
543
1931
803
Bites per house
Minutes
Total number of bites
0.0
10.0
0.0
10.0
true
true
"set setup-finished false" ""
PENS
"House 1" 1.0 0 -16777216 true "" "if num-houses >= 1 and setup-finished = true\n[\nplot [sum [nb-of-bites] of link-neighbors] of house (item 0 house-list)\n]"
"House 2" 1.0 0 -13840069 true "" "if num-houses >= 2 and setup-finished = true\n[\nplot [sum [nb-of-bites] of link-neighbors] of house (item 1 house-list)\n]"
"House 3" 1.0 0 -2674135 true "" "if num-houses >= 3 and setup-finished = true\n[\nplot [sum [nb-of-bites] of link-neighbors] of house (item 2 house-list)\n]"
"House 4" 1.0 0 -12345184 true "" "if num-houses >= 4 and setup-finished = true\n[\nplot [sum [nb-of-bites] of link-neighbors] of house (item 3 house-list)\n]"
"House 5" 1.0 0 -817084 true "" "if num-houses >= 5 and setup-finished = true\n[\nplot [sum [nb-of-bites] of link-neighbors] of house (item 4 house-list)\n]"
"House 6" 1.0 0 -1184463 true "" "if num-houses >= 6 and setup-finished = true\n[\nplot [sum [nb-of-bites] of link-neighbors] of house (item 5 house-list)\n]"

MONITOR
12
1046
82
1091
Total bites
sum [nb-of-bites] of humans
0
1
11

TEXTBOX
17
866
80
886
Counts
16
83.0
1

TEXTBOX
261
904
431
928
<- this affects sim speed
14
15.0
1

BUTTON
174
188
252
221
Calibrate
let tick-limit 5000\nif ticks > tick-limit\n[\n  output-print \"ERROR: RESET TICKS REQUIRED\"\n]\nif ticks = 0\n[\n  output-print \"INCREASE SPEED TO MAXIMUM PLEASE\"\n  ask tiger-mosquitos [die]\n]\n\nset calibration true\n\nif setup-finished = False [setup]\n\ngo\n\nif ticks > tick-limit\n[\n  output-print \"CALIBRATION COMPLETED\"\n  output-print \"\"\n  output-print \"INSTRUCTIONS:\"\n  output-print \"- Look at mosquito population chart.\"\n  output-print \"- Verify that NUM-TIGER-MOSQUITOS has been set to\"\n  output-print \"  a good value for the stabilized population.\"\n  output-print \"\"\n  output-print \"The stabalized value depends on:\"\n  output-print \"- MOSQUITO-SPAWN-PER-HOUR-AT-BORDERS\"\n  output-print \"- MOSQUITO-NATURAL-DEATH-CHANCE-PER-HOUR\"\n  set num-tiger-mosquitos round calibration-avg-population\n  stop\n]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
174
228
252
261
Reset ticks
set calibration False\nset setup-finished False\nreset-ticks
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
221
724
371
757
freeze-chemicals
freeze-chemicals
1
1
-1000

INPUTBOX
14
792
190
852
carboxylic-acid-parts-per-trillion
200.0
1
0
Number

INPUTBOX
201
792
356
852
trapchem-parts-per-trillion
200.0
1
0
Number

TEXTBOX
16
771
166
789
Detection limit for mosquitos:
11
0.0
1

SWITCH
1725
819
1825
852
calibration
calibration
0
1
-1000

MONITOR
1538
812
1709
857
Calibrated mosquito population
calibration-avg-population
0
1
11

CHOOSER
298
337
426
382
ticks-per-minute
ticks-per-minute
1 2 3 4
1

CHOOSER
298
387
427
432
chemical-steps-per-tick
chemical-steps-per-tick
1 2 3 4 5
1

MONITOR
12
994
179
1039
Total nb of gravid mosquitos
count tiger-mosquitos with [lifecycle-stage = \"gravid\"]
0
1
11

TEXTBOX
1834
826
1984
844
<- do not touch
14
15.0
1

@#$#@#$#@
## WHAT IS IT?

This simulation demonstrates the effect of mosquito traps in proximity to human dwellings. It specifically targets tiger mosquitos, a species that has evolved to prey on humans. Tiger mosquitos are known to be attracted to CO2, heat, movement, and chemicals emitted from the skin. The distribution of CO2 and chemicals is highly dependant on the wind. As such, this model incorporates both wind speed and orientation. A statistical approach is applied to the wind speed since the wind is never constant. Some variability to the orientation is also applied.

Since only female mosquitos feed on human blood and mating is out of scope, no male population is considered. The simulation examines the case where chemical attractions only happen during the meal-seeking phase.

The user can place traps and houses. Each house has humans in the vicinity. The traps release their chemicals and the humans release CO2 and carboxylic acids, a type of chemical that is released from the skin and attracts mosquitos. The mosquitos will bite humans if they are close (heat and movement aspect of their sensing). The number of mosquito bites per house is charted, allowing a full analysis of the role trap placement and wind play in the effectiveness of the trap(s). The number of trapped mosquitos is also counted.

## HOW IT WORKS

The model generates both static and moving turtles. The static turtles are the traps, houses, house fences and humans. This are items the user places (fences and humans are generated automatically when a house is placed). The moving turtles are tiger mosquitos and chem-transporters. Each transporter contains a certain amount of millimoles of a chemical to approximate chemical distribution. These transporters are hidden from the user. The modelled chemicals are those that attract tiger mosquitos: CO2, trap chemical, and carboxylic acids. Traps emit trap chemical. Humans emit CO2 and carboxylic acids.

The model is based around a time scale of 1 minute, but the user can select the desired number of ticks per minute. This allows finer grained mosquito movements. In addition, chemical generation and movement can be set to multiple loops per tick in order to smoothen even more their distribution. At minimum settings and high wind, the chemical distribution will be very poor and can be visualized. The map scale can be selected by the user. All movements are adjusted appropriately for the scale.

The movement of chem-transporters is based on diffusive and convective forces. Diffusion happens through a random walk that is calculated for a 5 dimensional space (North, South, East, West, and Up). The mean distance travelled is SQRT(5 * D * t), where D is the diffusion coefficient and t is the time step [1]. It is assumed that the trap chemical and the carboxylic acids have a diffusion coefficient similar to hexanoic acid. The values for the diffusion coefficients of CO2 and hexanoic acid are 0.224 cm2/s and 0.061 cm2/s, respectively [2]. As such, the mean speed of CO2 is 0.635 m/min and the mean speed for the other chemicals is 0.331 m/min. Diffusion is performed exclusively with the mean speed (no statistical distribution). At chemical generation, however, the diffusion speed is a random draw of values going from 0 to 2x the mean. Patches are updated every tick to get the average concentration and the gradient direction for each chemical. Each patch retrieves the number of millimoles from each chem-transporter in a certain radius and calculates the average concentration. Then each patch examines the concentrations in its neighboring patches to find the angle in which the gradient is increasing the most.

Chem transporters containing CO2 and carboxylic acids are hatched by humans. Trap chemical is hatched by traps. The production quantity is determined via two approaches. CO2 production is based on an average of 13.5 mmol/min per human. This is double the amount of CO2 that is exhaled by a human at rest (4 L/min at 4% concentration), but much lower than during physical exertion (50 L/min) [5]. The production of trap chemical and carboxylic acid is based on the following formula: rate = λ * (saturation concentration – concentration). The saturation concentration is calculated from the saturation partial pressure and is assumed to be similar to that of azaleic acid, which has a Psat of 7.61 x 10^-6 Pascals [6]. The parameter λ is a rate constant that was set to 0.2 min^-1. Approximately 7 mg/min of chemical is emitted with these parameters, which is not excessive for a first approximation. The correct consumption rate was not known during the development of this code. It is the responsability of the user to find the correct parameters for a given trap chemical.

Mosquitos’ move according to these chemical concentrations/gradients and the wind. If a chemical concentration is above the mosquito’s detection threshold then it will follow the gradient for that chemical, with some randomness added to the orientation. In the case where multiple chemicals are above the detection threshold, the concentrations are normalized according to their respective detection limits and then squared. The highest value determines which chemical will attract the mosquito. A sensitivity factor is included in order to allow the user to increase or decrease the weight of each value. It is a simple multiplier and is set to 1 for all chemicals by default. Mosquitos are attracted to CO2 starting at around 100ppmv, which is just under 5 mmoles/m3 [3]. This is the value used for the CO2 detection threshold. For the trap chemical and carboxylic acids, a value of 200 parts per trillion (volume) was chosen as the detection limit, but requires confirmation. The user may set these last two values.

Once a mosquito is within the “biting-distance” of a human (chosen as 8 meters), it has a chance to bite it (set to 20% and stored as a mosquito agent parameter). A successful bite may allow it to reach between 40% and 100% of its blood requirement. Once 100% is achieved, the mosquito changes from its “meal-seeking” phase to the “post-meal” phase. This is only 10 minutes and their movement is moderately oriented, allowing them to move away from their last host and no longer bite. Once they reach the end of this stage, they enter the “gravid” stage, which is the egg maturation phase. Once in gravid, the mosquitos no longer move nor bite.

Wind is generated via a Weiburn statistical distribution. This involves a scale-parameter (approximately the mean speed) and the shape-parameter. A speed is selected from the Weiburn distribution for each tick and applied to the entire map. The main wind orientation is set via a slider. When moving chemical transporters, each of them can deviate by a certain angle. This is called **local-wind-orientation-variability** and is set by default to 30 degrees (± 15 degrees).

Wind does not affect the directional movement of the mosquitos. It is known that they stay within their breeding habitat despite the wind, but that they do not fly when the wind is too strong [3]. The mosquitos' speeds vary and are drawn at random between a minimum and a maximum value. The mosquitos compensate for the wind, including reducing their speed if necessary. This is done in a way to prevent bias of movement in the direction of the wind. A conservative estimate of net directional flight speed is used, going from 1 to 15 meters per minute regardless of whether the mosquito is on a chemical trail or not.

The map is open and the mosquitos can disappear off the edges (they die). To compensate for this, there is a slider that allows the user to set a spawn rate. The code is written such that 95% are spawned at the borders and the other 5% anywhere on the map.Mosquitos spawned at the edges can appear anywhere up to the distance corresponding to their max speed. This helps to maintain a correct distribution of the mosquito population. A calibration button allows a user to determine the population corresponding to a given combination of spawn rate and natural death. Once this is calculated, the model automatically updates the starting population, but the user can change it if desired.

Similar to the “biting-distance”, there is also a “trapping-distance” (chosen as 5 meters). If a mosquito is within this distance, then there is an 80% chance per minute that it is captured. Traps are placed manually by the user. They only emit trap chemical.

Houses are also placed manually by the user. Three humans are placed around each house within a certain radius. A fence is placed around the house based on this same radius. The fences only provide visual feedback to the user. These humans emit CO2 and carboxylic acids. They have a chance to kill mosquitos that are in biting range.


## HOW TO USE IT

### CALIBRATION STEP (REQUIRED)
Calibration is required to appropriately set the initial mosquito population so that it is coherent with the spawning rate and the natural death rate. The following should be done to properly perform a calibration:

1. Set the **meters-per-patch** (as desired)
2. Set **mosquito-spawn-per-minute** (as desired)
3. Set **mosquito-natural-death-chance-per-hour** (as desired)
4. Click on **“Reset-ticks”**
5. Set speed to maximum
6. Click on **“Calibrate”**
7. Once finished (10000 ticks), the model audomatically sets the starting population **num-tiger-mosquitos** to the calibrated value
8. Verify that this value is correct by looking at the mosquito population chart
9. Adjust the speed to “normal”

**NOTE:** a calibration switch is present on the dashboard. The user should not interact with it. It is managed by the model and is only present due to limitations in the NetLogo language.

### POST CALIBRATION
After a calibration, the following parameters should not be changed (except for a new calibration):

1. **meters-per-patch**
2. **mosquito-spawn-per-minute**
3. **mosquito-natural-death-chance-per-hour**
4. **num-tiger-mosquitos**

However, **mosquito-spawn-per-minute** and **num-tiger-mosquitos** are linearly correlated, so a manual adjustment post-calibration can be done in a quick and dirty way. The natural death generally has a smaller effect.

### SETUP
Setup is done in the following manner:

1. Make sure the **"freeze-chemicals"** switch is in the off position.
2. Select the number of desired traps
3. Select the number of desired houses
4. Ideally, set all the parameters to the desired values
5. Click the setup button
6. Place the traps and houses one at a time. House fences cannot go beyond the edge of the map.

### PARAMETER ADJUSTMENTS
Parameter adjustments are as follows:

1. **heatmap-choice**: select the chemical color mapping as desired
2. **sensitivity-trapchem**: a weight for the relative importance of the trapchem compared to the CO2 and carboxylic acids. It is a simple multiplier of importance.
3. **sensitivity-co**2: a weight for the relative importance of CO2 compared to the trapchem and carboxylic acids. It is a simple multiplier of importance.
4. **sensitivity-carboxyl**: a weight for the relative importance of carboxylic acids compared to the CO2 and the trapchem. It is a simple multiplier of importance.
5. **percent-chem-loss**: the percent of all chemicals that dissappear each tick. It can be considered as the upward loss into the atmosphere, hence the 20% maximum value.
6. **carboxylic-acids-parts-per-trillion** is the lower detection limit of carboxylic acids for mosquitos.
7. **trapchem-parts-per-trillion** is the lower detection limit of trap chemical for mosquitos.
8. **scale-parameter**: adjusts the mean wind speed
9. **shape-parameter**: adjusts the distribution of possible wind speeds
10. **wind-orientation**: adjusts the wind orientation, with 0 being North, 90 being East, etc.
11. **local-wind-orientation-variability**: the total variation possible in wind orientation each time an individual chem-transporter is moved. A value of 10 means that the wind can go -5° or + 5° relative to the main orientation.

### LIVE ADJUSTMENTS
Live adjustments are possible for **ALL** parameters **EXCEPT**:
- **meters-per-patch**
- **num-traps**
- **num-houses**
- **num-tiger-mosquitos**
- **carboxylic-acids-parts-per-trillion**
- **trapchem-parts-per-trillion**
- **ticks-per-minute**
- **chemical-steps-per-tick**

Set the **"freeze-chemicals"** switch to ON only after starting the model. This will freeze the chemical states (no updates, but the concentrations and gradients will remain).


## THINGS TO NOTICE

At high wind speeds, the mosquitos will be still much of the time. Their average speed will also be slower. They will not entirely stop moving, because sometimes the wind is slow. Take a look at the distribution plot to get an idea of what wind speeds you can expect.

A blue arrow in the upper-right corner of the map indicates the current wind direction.

Mosquito colors are as follows:
- red = "meal-seeking"
- black = "post-meal"
- gray = "gravid"

The density of "meal-seaking" mosquitos decreases around the traps and houses. This has three causes:
- mosquitos arrive principally from the edges
- traps eliminate mosquitos
- mosquitos that have fully fed enter the gravid phase

The houses are labelled. The number of bites per house is plotted to the right of the map. It helps evaluate which houses benefit from the traps.


## THINGS TO TRY

Try with only 1 trap and 1 house initially in order to get a better feel for the simulation. Every extra trap and house will slow down the model because they generate additional chemical transporters.

Try the "continuous" update to see how things change during a tick. Since chemicals are usually updated multiple times per tick and the number of chem-transporters is usually quite large, the model is often slow. The user may accelarate the model at the expense of "freezing" the chemicals in the current state. To do this, you can turn on the **"static-chemicals"** switch to stop moving/generating/updating the chemicals. This can allow for a better analysis of how the mosquitos behave within the chemical clouds. This will work best at maximum **ticks-per-minute¨** and **chemical-steps-per-tick**. 

See what happens when you put a trap directly upwind of a house. What happens if it is downwind?

What happens when you constantly change the wind direction?

## EXTENDING THE MODEL

A primary need for this model is a more accurate estimation of the detection limits for the 3 different chemicals. It could also benefit from a more sophisticated mosquito movement algorithm, adjusting their speeds according to what chemical trail they are following. The gradient and concentration may affect their speed. Also, any time a mosquito is close to a human it should ideally change its orientation towards that human, effectively accounting for the fact that mosquitos are also drawn to heat and movement. For the moment the orientation is only a function of the chemicals, but they bite if a human is close.

Another primary need for this model is a statistical distribution-based diffusion system for the chemical transporters.

The speed of this simulation is an issue. It is however an excellent candidate for multi-threading if and when NetLogo supports it. The large number of chemical transporters is the culprit, but the code that deals with them could be parallelized as it is largely independant of other elements in the code. In its current state, the number of generated chem-transporters may be optimized for speed, at the potential cost of precision. As long as the gradients remain coherent, then the simulation should remain functional.

If multi-threading becomes an option, adding the complete lifecycle of mosquitos could be a possibility. Notably, water spots could be added to draw in the gravid mosquitos (via chem-transporters containing water) and allow them to lay their eggs once the gravid cycle reaches its end.

Adding wildlife and roaming humans would also make the simulation more realistic, though understanding the effect of traps may become less clear. This would require moving the humans at the same time as the mosquitos. A starter code is provided, but commented out.

The simplist modification would be to have the traps release repulsive chemicals. The gradient orientation could simply be flipped for the trap chemical.


## NETLOGO FEATURES

The diffusion feature of NetLogo was not used because it could not be applied correctly with wind convection. Thus, hidden turtles (chem-transporters) carry the chemicals and split in two every 15 meters in order to compensate for their diminishing density.

## RELATED MODELS

Ants - this model available in the library shows how ants change their direction based on the concentration gradient of a chemical.

## CREDITS AND REFERENCES

[1] https://www.compadre.org/nexusph/course/Diffusion_and_random_walks

[2] https://tsapps.nist.gov/publication/get_pdf.cfm?pub_id=957163

[3] https://malariajournal.biomedcentral.com/articles/10.1186/s12936-018-2197-5

[4] https://publichealth.jhu.edu/2023/the-chemistry-of-mosquito-attraction

[5] Kleinebecker, Till. (2021). Re: How much CO2 does an average person emit by breathing?. Retrieved from: https://www.researchgate.net/post/How_much_CO2_does_an_average_person_emit_by_breathing/618148893cc7f50d5370559e/citation/download.

[6] https://acp.copernicus.org/articles/23/6863/2023/

## DEVELOPPER
Author: Andrew Wieber
Date: 7 June 2024

## COPYRIGHT AND LICENSE
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.
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

arrow 3
true
0
Polygon -7500403 true true 135 255 105 300 105 225 135 195 135 75 105 90 150 0 195 90 165 75 165 195 195 225 195 300 165 255

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

fence-perimeter
false
3
Rectangle -6459832 true true 15 15 15 90
Rectangle -6459832 true true 0 0 15 285
Rectangle -6459832 true true 285 15 300 300
Rectangle -6459832 true true 15 0 300 15
Rectangle -6459832 true true 0 285 285 300

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

hawk
true
0
Polygon -7500403 true true 151 170 136 170 123 229 143 244 156 244 179 229 166 170
Polygon -16777216 true false 152 154 137 154 125 213 140 229 159 229 179 214 167 154
Polygon -7500403 true true 151 140 136 140 126 202 139 214 159 214 176 200 166 140
Polygon -16777216 true false 151 125 134 124 128 188 140 198 161 197 174 188 166 125
Polygon -7500403 true true 152 86 227 72 286 97 272 101 294 117 276 118 287 131 270 131 278 141 264 138 267 145 228 150 153 147
Polygon -7500403 true true 160 74 159 61 149 54 130 53 139 62 133 81 127 113 129 149 134 177 150 206 168 179 172 147 169 111
Circle -16777216 true false 144 55 7
Polygon -16777216 true false 129 53 135 58 139 54
Polygon -7500403 true true 148 86 73 72 14 97 28 101 6 117 24 118 13 131 30 131 22 141 36 138 33 145 72 150 147 147

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
