Class {
	#name : #SoilIndexManager,
	#superclass : #Object,
	#instVars : [
		'segment',
		'indexes',
		'semaphore'
	],
	#category : #'Soil-Core-Model'
}

{ #category : #accessing }
SoilIndexManager class >> indexClassFromFile: aFileReference [ 
	| stream pageCode headerPage |
	stream := aFileReference binaryReadStream.
	pageCode := stream next.
	stream close.
	headerPage :={ SoilSkipListHeaderPage . SoilBTreeHeaderPage } detect: [ :each | each pageCode = pageCode ].
	^ headerPage indexClass
]

{ #category : #visiting }
SoilIndexManager >> acceptSoil: aSoilVisitor [ 
	^ aSoilVisitor visitIndexManager: self 
]

{ #category : #accessing }
SoilIndexManager >> at: indexId ifAbsent: aBlock [ 
	^ semaphore critical: [  
		indexes 
			at: indexId 
			ifAbsentPut: [ 
				self 
					loadIndexWithId: indexId 
					ifNone: aBlock  ] ]
		
]

{ #category : #accessing }
SoilIndexManager >> at: indexId put: aSoilIndex [
	^ semaphore critical: [  
		indexes 
			at: indexId
			put: aSoilIndex thePersistentInstance ]
]

{ #category : #'open/close' }
SoilIndexManager >> close [
	semaphore critical: [  
		indexes copy keysAndValuesDo: [ :id :index |
			index close.
			indexes removeKey: id ] ]
]

{ #category : #api }
SoilIndexManager >> createIndexWithId: indexId class: aClass [ 
	^ aClass new 
		path: (self pathFor: indexId);
		initializeFilesystem;
		initializeHeaderPage
]

{ #category : #accessing }
SoilIndexManager >> dirtyIndexes [
	^ indexes select: [ :each | each hasDirtyPages ]
]

{ #category : #accessing }
SoilIndexManager >> flush [
	self dirtyIndexes copy do: [ :index | 
		index cleanUpToVersion: (self soil transactionManager smallestReadVersion) ]
]

{ #category : #flushing }
SoilIndexManager >> flushIndexes [
	indexes do: #flushCachedPages
]

{ #category : #testing }
SoilIndexManager >> hasIndexId: aString [ 
	^ (self pathFor: aString) exists
]

{ #category : #accessing }
SoilIndexManager >> indexes [

	^ indexes
]

{ #category : #initialization }
SoilIndexManager >> initialize [ 
	super initialize.
	indexes := Dictionary new.
	semaphore := Semaphore forMutualExclusion
]

{ #category : #initialization }
SoilIndexManager >> initializeFilesystem [
	self path ensureCreateDirectory 
]

{ #category : #api }
SoilIndexManager >> loadIndexWithId: indexId ifNone: aBlock [
	| path |
	path := self path / indexId , #index.
	^ path exists
		ifTrue: [ 
			(self class indexClassFromFile: path) new 
				path: path ]
		ifFalse: [ aBlock value ]
]

{ #category : #'open/close' }
SoilIndexManager >> open [
	
]

{ #category : #accessing }
SoilIndexManager >> path [ 
	^ segment path / #indexes
]

{ #category : #accessing }
SoilIndexManager >> pathFor: indexId [ 
	^ self path / indexId , #index
]

{ #category : #accessing }
SoilIndexManager >> segment [
	^ segment
]

{ #category : #accessing }
SoilIndexManager >> segment: aSOObjectSegment [ 
	segment := aSOObjectSegment 
]

{ #category : #accessing }
SoilIndexManager >> soil [ 
	^ segment soil 
]

{ #category : #writing }
SoilIndexManager >> writeContentsToDisk [
	segment soil setup isFsyncEnabled ifTrue: [  
		self indexes do: [ :each | each writeContentsToDisk ] ]
]
