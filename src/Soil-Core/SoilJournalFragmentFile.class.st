Class {
	#name : #SoilJournalFragmentFile,
	#superclass : #SoilBinaryFile,
	#instVars : [
		'path',
		'databaseJournal'
	],
	#category : #'Soil-Core-Journal'
}

{ #category : #'file names' }
SoilJournalFragmentFile class >> filenumberFromFilename: aString [ 
	^ (ByteArray readHexFrom: aString) asInteger
]

{ #category : #accessing }
SoilJournalFragmentFile class >> path: aFileReference [ 
	^ self new 
		path: aFileReference 
]

{ #category : #versions }
SoilJournalFragmentFile class >> version [
	^ 1
]

{ #category : #visiting }
SoilJournalFragmentFile >> acceptSoil: aSoilVisitor [ 
	aSoilVisitor visitJournalFragmentFile: self
]

{ #category : #writing }
SoilJournalFragmentFile >> appendEntries: aCollection [ 
	| position lock |
	"append all entries in the collection using a single lock, 
	flush and sync operation."
	lock := stream lockAppendingFor: self.
	[ 
	 	"when the lock is in place it is safe the set the file 
		to its end"
		stream setToEnd.
		position := stream position.
		aCollection do: [ :entry | entry writeOn: stream ].
		"after all entries are written we can have a single flush
		and potential sync to disk"
		stream flush.
		databaseJournal fragmentFileWritten: self  ]
			ensure: [ lock release ].
	^ position

]

{ #category : #writing }
SoilJournalFragmentFile >> appendEntry: aSoilJournalEntry [ 
	| position lock |
	lock := stream lockAppendingFor: self.
	[ 
	 	"when the lock is in place it is safe the set the file 
		to its end"
		stream setToEnd.
		position := stream position.
		aSoilJournalEntry writeOn: stream.
		stream flush.
		databaseJournal fragmentFileWritten: self  ]
			ensure: [ lock release ].
	^ position

]

{ #category : #accessing }
SoilJournalFragmentFile >> atEnd [
	^ stream atEnd
]

{ #category : #accessing }
SoilJournalFragmentFile >> basename [ 
	^ path basename
]

{ #category : #copying }
SoilJournalFragmentFile >> copyTo: aPath [ 
	path copyTo: aPath
]

{ #category : #'instance creation' }
SoilJournalFragmentFile >> create [
	path ensureCreateFile
]

{ #category : #accessing }
SoilJournalFragmentFile >> created [
	self stream position: self createdPosition.
	^ DateAndTime fromUnixTime: (stream next: self createdSize) asInteger
]

{ #category : #accessing }
SoilJournalFragmentFile >> createdPosition [
	^ self versionPosition + self versionSize 
]

{ #category : #accessing }
SoilJournalFragmentFile >> createdSize [
	^ 6
]

{ #category : #accessing }
SoilJournalFragmentFile >> currentLogSequenceNumber [ 
	^ SoilLogSequenceNumber 
		fileNumber: (self class filenumberFromFilename: path basename) 
		offset: stream position 
]

{ #category : #accessing }
SoilJournalFragmentFile >> dataPosition [
	^ self createdPosition + self createdSize 
]

{ #category : #accessing }
SoilJournalFragmentFile >> databaseJournal: aSoilPersistentDatabaseJournal [
	databaseJournal := aSoilPersistentDatabaseJournal 
]

{ #category : #journal }
SoilJournalFragmentFile >> entries [
	| entries |
	entries := OrderedCollection new.
	self entriesDo: [ :entry |
		entries add: entry ].
	^ entries 
]

{ #category : #journal }
SoilJournalFragmentFile >> entriesCollect: aBlock [
	| col |
	col := OrderedCollection new.
	self entriesDo: [ :entry |
		col add: (aBlock value: entry) ].
	^ col 
]

{ #category : #journal }
SoilJournalFragmentFile >> entriesDo: aBlock [
	| position oldPosition |
	self stream position: self dataPosition.
	oldPosition  := 0.
	[ stream atEnd ] whileFalse: [ 
		position := stream position.
		"call block with three arguments: entry, file position, length"
		aBlock 
			cull: (SoilJournalEntry readFrom: stream)
			cull: position
			cull: position - oldPosition.
		oldPosition := position ].

]

{ #category : #searching }
SoilJournalFragmentFile >> entriesMatching: aBlock [
	^ self transactionJournals flatCollect: [ :journal |
		journal entriesMatching: aBlock ]
]

{ #category : #accessing }
SoilJournalFragmentFile >> fileNumber [
	^ self class filenumberFromFilename: path basename
]

{ #category : #accessing }
SoilJournalFragmentFile >> filename [ 
	^ self path basename
]

{ #category : #accessing }
SoilJournalFragmentFile >> firstTransactionId [
	self stream position: self dataPosition.
	self flag: #todo.
	"we skip the "
	((SoilJournalEntry readFrom: self stream) class = SoilCheckpointEntry) ifFalse: [ 
		Error signal: 'fragment file should start with a checkpoint entry' ].
	^ SoilTransactionJournalEntry readTransactionIdFrom: stream
]

{ #category : #testing }
SoilJournalFragmentFile >> hasSpace [
	"a fragment file when writing to it must be smaller be with a 
	file size of 24 bit = 16MB"
	^ stream size < (2 raisedTo: 24)
]

{ #category : #initialization }
SoilJournalFragmentFile >> initializeCreated [
	| timestamp |
	timestamp := DateAndTime now asUnixTime.
	stream 
		position: self createdPosition;
		nextPutAll: (timestamp asByteArrayOfSize: self createdSize);
		flush
]

{ #category : #initialization }
SoilJournalFragmentFile >> initializeStart [ 
	self initializeVersion.
	self initializeCreated 
]

{ #category : #initialization }
SoilJournalFragmentFile >> initializeVersion [ 
	self stream position: self headerSize.
	stream next: self class version.

]

{ #category : #inspector }
SoilJournalFragmentFile >> inspectionTransactionJournals: aBuilder [
	<inspectorPresentationOrder: 0 title: 'Transaction journals'>

	^ aBuilder newTable
		items: (self transactionJournals reverse);
		addColumn: (SpCompositeTableColumn new
			title: '#';
			width: 80;
			addColumn: (SpStringTableColumn evaluated: [:each | each index ]));
		addColumn: (SpStringTableColumn new 
			title: #read;
			evaluated: #readVersion;
			width: 50);
		addColumn: (SpStringTableColumn new 
			title: #duration;
			evaluated: #duration;
			width: 50);
		addColumn: (SpStringTableColumn new 
			title: #created;
			evaluated: #createdAt);
		addColumn: (SpStringTableColumn new
			title: #commit;
			evaluated: #committedAt);
		yourself
]

{ #category : #'open/close' }
SoilJournalFragmentFile >> open [
	self isOpen ifTrue: [ self error: 'File already open' ].
	stream := SoilLockableStream path: path 
]

{ #category : #accessing }
SoilJournalFragmentFile >> path [
	^ path
]

{ #category : #accessing }
SoilJournalFragmentFile >> path: aFileReference [
	path := aFileReference asFileReference 
]

{ #category : #accessing }
SoilJournalFragmentFile >> position: anInteger [ 
	stream position: anInteger 
]

{ #category : #utilities }
SoilJournalFragmentFile >> prefix [
	^ 'SOIL|JOURNAL FRAGMENT' asByteArray
]

{ #category : #printing }
SoilJournalFragmentFile >> printOn: aStream [ 
	aStream 
		<< 'journal segment file: '
		<< path asString
]

{ #category : #initialization }
SoilJournalFragmentFile >> setToEnd [
	stream setToEnd
]

{ #category : #accessing }
SoilJournalFragmentFile >> setToStart [
	self stream position: self dataPosition
]

{ #category : #accessing }
SoilJournalFragmentFile >> size [ 
	^ stream size 
]

{ #category : #journal }
SoilJournalFragmentFile >> transactionJournals [
	| transactionJournals entry |
	self stream position: self dataPosition.
	transactionJournals := OrderedDictionary new.
	[ stream atEnd ] whileFalse: [  
		entry := SoilJournalEntry readFrom: stream.
		entry isTransactionEntry ifTrue: [ 
			(transactionJournals 
				at: entry transactionId
				ifAbsentPut: [ SoilTransactionJournal new index: entry transactionId ])
					addEntry: entry ] ].
	^ transactionJournals values
]

{ #category : #accessing }
SoilJournalFragmentFile >> version [
	self stream position: self versionPosition.
	^ stream next asInteger
]

{ #category : #versions }
SoilJournalFragmentFile >> versionPosition [
	^ self headerSize 
]

{ #category : #versions }
SoilJournalFragmentFile >> versionSize [
	^ 1
]

{ #category : #writing }
SoilJournalFragmentFile >> writeContentsToDisk [ 
	databaseJournal soil setup isFsyncEnabled ifTrue: [ 
		stream sync ]
]
