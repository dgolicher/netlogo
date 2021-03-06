extensions [ gis rserve];;This makes the gis extension available. 
;; It is provided by default in netlogo 5
;;
;;The netlogo lists into which the gis layers are loaded have to be defined as 
;; globals. So we have "wood" for the polygons and centroids
;; There is also a global scale factor that is used to translate meters into 
;; Netlogo units. It took me a while to see why this was necessary, as I assumed
;; it was all taken care of in the "setup-gis-world" function
;;In fact it is very important to get this right when loading rasters and setting patch variables from them.

globals [path bbox edge2edge centroids scale_factor clustern]

;; The global variables include the names that the GIS layers will have when imported
;; The scale_factor is the ratio between the width of a netlogo patch and the unit of 
;; measurement (m) in the GIS layer.

breed [habitats habitat]
;; The nodes are habitats. They are given a breed name

habitats-own [gid area perimeter occupied? cluster]
;;The properties of the habitats could be extended in a more detailed model
links-own [dist]
;; Links may own the property of distance, if measured. In a model with edge-edge distance this
;; will become very important.

to startup 
  ;;rserve:close
  rserve:init 6311 "localhost"
  clear-all
  set clustern 1
  set scale_factor 100
  ;; Do not forget the scale factor! 1 km will be 10 units in the model.
   ;; Import the polygons
   set bbox gis:load-dataset "bbox.shp"
   set edge2edge gis:load-dataset ("edge_to_edge2000.shp")
   set centroids gis:load-dataset "NFAnWood_Centroids.shp"
  ;;Import the centroids
   setup-gis-world gis:envelope-of bbox  1.8
  ;; The line above is vital. Check the setup-world-function below for more details.
  ;; gis:draw centroids 2 
  ;; This does what it says. The centroids are now drawn on the interface. But they may be 
  ;; overwritten once they have been converted into "turtles" of the habitat breed using the 
  ;; code below.
  ;; Notice that we need to cycle through the feature list. Each member of this list
  ;; coincides with a row in the vector layer attributes table.
 
   foreach gis:feature-list-of centroids [
     ;; In this case there should only be one vertex, but use the code in the conventional 
     ;; Gis extension example for  safety.
       let location gis:location-of (first (first (gis:vertex-lists-of ?)))
       ;; Now simply place a habitat turtle at each position and set all its attributes-
       ;; Some of these are read from the vector layer.
       create-habitats 1 [
        set shape "circle"
        set color green
        set xcor item 0 location
        set ycor item 1 location
        set gid gis:property-value ? "gid"
        set area gis:property-value ? "area" / 10000 ;;Area in square meters to hectares 
        set size 2 + sqrt(area / 3) ;; Arbitrary, for visualisation. Don't want very small areas invisible nor large areas too big
        set occupied? FALSE
        set perimeter gis:property-value ? "perimeter"
       ]]
end




to setup
  make-network
  reset-ticks
  clear-all-plots
end

to go
  run-a-step
  tick
  if count habitats with [occupied? = TRUE] = 0 [stop]
end

to-report sdistances
  foreach gis:feature-list-of edge2edge [
        let to_gid gis:property-value ? "to_gid"
        let from_gid gis:property-value ? "from_gid"
        let dist gis:property-value ? "distance"
  show dist
  ]
end
to make-network
    clear-links
      foreach gis:find-less-than edge2edge "distance" sep_dist [
        let to_gid gis:property-value ? "to_gid"
        let from_gid gis:property-value ? "from_gid"
        let dist gis:property-value ? "distance"
      if to_gid != from_gid [
     ask one-of habitats with [gid = from_gid]
    [create-link-with one-of other habitats with [gid = to_gid ]
      [set dist dist
        set thickness 1
        set color black]     
    ]]]
     ask habitats [ 
    set cluster 0
    set color green]
    find-clusters
    start-metapop
end

to setup-gis-world [env patchsize]
  ;; The bounding box is read from the gis layer that is passed to this function. See the call in "setup".
  let gis-width item 1 env - item 0 env
    ;; Find the width of the box in GIS units (probably meters)
  let gis-height item 3 env - item 2 env
    ;; Find the height in GIS units.
  resize-world 0 gis-width / scale_factor  0  gis-height / scale_factor
     ;; This is VITAL: The underlying coordinate system is resized. This is not explicit in the examples provided.
     ;; It is necessary to ensure that when a call is made to a function such as "in-radius" there is a clear 
     ;; reltionship between the units used by netlogo and the GIS units. In this case the scale factor of 100 results in
     ;; a corrspondence of 1 unit in netlogo space to 100 m in gis space. This is not obvious in examples
     ;; which do not mix the two. It is particularly important when rasters are imported, as this is all related to resolution
     ;; and grain size.
  set-patch-size patchsize
    ;; The patch size could be derived automatically, but here it is set in the function call. 
    ;; Again be careful here. This controls the grain size of the diplay. 
  ask patches [set pcolor white]
  gis:set-world-envelope env
 end  


to start-metapop
  ask n-of 50 habitats 
  [set color red
    set occupied? TRUE
  ]
end

to run-a-step
  ask habitats [
  go-extinct
  get-colonised
  ]
end

to go-extinct
  ;; Drop in a function here. This one uses exponential decay and has 
  ;; the paremeter that represents the area for which there is a 50% extinction rate
  let lambda ln(2) / half_area
  let ext_prob 100 * exp(- lambda * area) 
    if random 100 < ext_prob [
      set occupied? FALSE
      set color green]
end

to-report extinction-prob
    let lambda ln(2) / half_area
    let ext_prob 100 * exp(- lambda * area) 
    report ext_prob
end

to get-colonised
      if any? link-neighbors with [occupied? = TRUE] AND  random 100 < col_prob
      [set occupied? TRUE
       set color red]

end



  to add-google
    import-drawing "newforest.png"
  end
   to add-sat
    import-drawing "newforestsat.png"
  end
   
   
 to find-clusters
   ;; This is taken from one of the code examples in the model library
   ask habitats[
  loop [
    let seed one-of habitats with [cluster = 0]
    ;; if we can't find one, then we're done!
    if seed = nobody [ stop ]
    ;; otherwise, make the habitat the "leader" of a new cluster
    ;; by assigning itself to its own cluster, then call
    ;; grow-cluster to find the rest of the cluster
    ask seed [
    set clustern clustern + 1
     set cluster clustern
      grow-cluster ]
  ]
   ]
   
end 

to grow-cluster  
  if any? link-neighbors with [cluster = 0] [
    ask link-neighbors with [cluster = 0] [ 
      set cluster clustern
      ;;set color cluster
      grow-cluster
    ]
  ]
end

to-report max-size
let clusterids (remove-duplicates [cluster] of habitats with [occupied? = TRUE])
let cluster-counts map [ count habitats with [ cluster = ?  and occupied? = TRUE ] ] clusterids
ifelse length cluster-counts > 0 [report max  cluster-counts] [report 0]
end

to-report nmetas
report length  remove-duplicates [cluster] of habitats with [occupied? = TRUE]
end 

to-report nclusters
 report length remove-duplicates [cluster] of habitats
end

to-report npops
  report count habitats with [occupied? = TRUE]
  end


to R-show-func
  rserve:put "halfarea" half_area
  rserve:eval "area<-1:500"
  rserve:eval "lambda<-log(2) / halfarea"
  rserve:eval "ext_prob<-100 * exp(- lambda * area)"
  rserve:eval "plot(ext_prob~area,type=\"l\",lwd=2,col=2,main=\"Relationship between area and extinction probability\")"
 
end
;;It can be quite frustrating to send each command through reserve:eval, especially as it seems to be impossible to build functions.
;;A simple solution is to source in a script that can be run and tested first with dummy input outside Netlogo

to R-show-func2
  rserve:eval "setwd(\"/home/duncan/Dropbox/Public/netlogo/models/MyModels/Edge2EdgeMetaPop\")"
  rserve:put "halfarea" half_area
  (rserve:putagentdf "d" habitats "area")
  rserve:eval "source(\"test.r\")"
 
end


to clear-r-fig
rserve:eval "if(dev.cur()>1)dev.off()"
end




@#$#@#$#@
GRAPHICS-WINDOW
384
10
1225
566
-1
-1
1.8
1
10
1
1
1
0
1
1
1
0
461
0
291
0
0
1
ticks
30.0

BUTTON
7
10
80
43
NIL
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
201
10
332
43
Google image
add-google
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
9
149
181
182
sep_dist
sep_dist
0
1000
400
50
1
NIL
HORIZONTAL

BUTTON
97
10
160
43
NIL
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
4
55
176
88
col_prob
col_prob
0
100
32
1
1
NIL
HORIZONTAL

SLIDER
6
100
178
133
half_area
half_area
10
500
90
10
1
NIL
HORIZONTAL

PLOT
11
272
361
519
Number of occupied patches
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"N" 1.0 0 -2674135 true "" "plot npops"
"N in largest" 1.0 0 -14730904 true "" "plot max-size"

BUTTON
203
50
307
83
Sat image
add-sat
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
199
89
327
122
NIL
clear-drawing
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
192
138
266
183
NIL
nclusters
17
1
11

MONITOR
283
140
346
185
NIL
nmetas
17
1
11

BUTTON
36
222
163
255
NIL
R-show-func2
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
169
230
269
263
NIL
clear-r-fig
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

Thi is a trial of the rserve extension. The buttons run an R script from within Netlogo. It will only work after installing the R sever and starting it running with **R CMD Rserve**

Also find and change the path on this line in order to match the directory where the test.r file has been placed.

**rserve:eval "setwd(\"/home/duncan/Dropbox/Public/netlogo/models/MyModels/Edge2EdgeMetaPop\")"**

This is a very simple implementation of a Levins type metapopulation. 
In this model extinction is a function of patch area. The user can set a value for the 
patch area at which the rate of extinction is 50%. This uses an exponential function so small patches will have much greater extinction rates and large patches will be quite stable.
There is also a small stochastic component to extinction.This could be made into an additional parameter.

If an unoccupied patch has any linked patch which is occupied it can be recolonised with a certain probability (col_prob expressed as % in the interface)

## HOW IT WORKS

Centroids are loaded using the GIS extension. However in this version the links are provided by loading a file containing linestrings of known length that represents the shortest edge to edge distance between patches. This layer has been built using a query in PostGIS.

http://duncanjg.wordpress.com/2012/09/23/edge-to-edge-distance-using-postgis/

This greatly improves the way the model handles connectivity. The improvement can best be seen when the vector polygons are added, as the model will connect large patches much better than the more simplistic version using distances between centroids.

## HOW TO USE IT

As the model stands it is still only useful for teaching the concept.
Sensitivity could be analysed using the behaviour space tool. While the model is too simplistic to represent any real situation it is paramaterised using real GIS data and therefore can be related to a known landscape. In this case, the New Forest, but other vector layers can easily be used.


## THINGS TO NOTICE

The model now takes into account the area of the habitat when evaluating extinction risk. So the model can simulate  source - sink dynamics.

Notice that the grey links are between centroids as before. Their "distance" property however is determined edge to edge. So long lines may in fact represent short distances. The reverse of the tube map!


## THINGS TO TRY

Change any of the parameters.
Watch the ouptut in order to see on which parts of the network the populations persist.

## EXTENDING THE MODEL

Many more realistic elements could be built from here. 
As the habitat nodes do know about their area this could fairly easily be incorporated in the model True interpatch distances are also known, so dispersal could be made more realistic. If cost surfaces were included it would probably be better to use an individual based ABM rather than patch based.

## NETLOGO FEATURES

Note the simplicity of the code for actually making the model run.

## RELATED MODELS

This is a very similar little model in R.
http://duncanjg.wordpress.com/2008/02/07/simple-source-sink-model/

## CREDITS AND REFERENCES

Duncan Golicher
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
NetLogo 5.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
