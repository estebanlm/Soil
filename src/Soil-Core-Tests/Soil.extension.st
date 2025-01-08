Extension { #name : #Soil }

{ #category : #'*Soil-Core-Tests' }
Soil classSide >> inMemory [ 
	^ self new 
		path: FileSystem memory root
]
