Extension { #name : #SoilBehaviorDescription }

{ #category : #'*Soil-Core' }
SoilBehaviorDescription classSide >> metaId [
	"the id of the class is alway 2 and pre-initialized to break recursion"
	^ SoilObjectId segment: 0 index: 2
]
