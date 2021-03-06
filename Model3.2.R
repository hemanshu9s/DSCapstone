# SETUP #
gc()
setwd("C:/Users/Michael/SkyDrive/Code/GitHub/DSCapstone/Coursera-SwiftKey/final/en_US/twit10")
library(tm)

# FUNCTION DEFINITIONS #

# Make Corpus and do transformations only
makeCorpus<- function(x) {
corpus<-Corpus(VectorSource(x))
corpus <- tm_map(corpus, stripWhitespace)
corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, removeWords, stopwords("english"))
corpus <- tm_map(corpus, stemDocument)
corpus<- tm_map(corpus,removePunctuation)
corpus<- tm_map(corpus,removeNumbers)
return(corpus)
}

# Make Corpus, do transformations,  then TDM
makeTDM <- function(x) {
corpus<-Corpus(VectorSource(x))
corpus <- tm_map(corpus, stripWhitespace)
corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, removeWords, stopwords("english"))
corpus <- tm_map(corpus, stemDocument)
corpus<- tm_map(corpus,removePunctuation)
corpus<- tm_map(corpus,removeNumbers)
tdm<-TermDocumentMatrix(corpus)
tdm<-removeSparseTerms(tdm,0.50)
return(tdm)}

# TrigramTokenizer function
library(rJava) # Is this really needed?
library(RWeka)
TrigramTokenizer <- function(x) NGramTokenizer(x, Weka_control(min = 3, max = 3))

# Make Corpus, Transform, Make Trigram TDM
makeTriTDM <- function(x) {
corpus<-Corpus(VectorSource(x))
corpus <- tm_map(corpus, stripWhitespace)
corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, removeWords, stopwords("english"))
corpus <- tm_map(corpus, stemDocument)
corpus<- tm_map(corpus,removePunctuation)
corpus<- tm_map(corpus,removeNumbers)
tdm<- TermDocumentMatrix(corpus, control = list(tokenize = TrigramTokenizer))
tdm<-removeSparseTerms(tdm,0.20)
return(tdm)}

## DATA MUNGING ##

# 1. Corpus, transformations, and TDM Creation
#=============================================#

# First I use a Unix Shell command to split the text file into 20,000 lines each chunks:
# split --numeric-suffixes -a 4 --lines=20000 en_US.twitter.txt twitter

#initialize a list to hold our data
twit<-list()

# Reach chunks into a list
for (i in 0:118) {
i4<-formatC(i,width=4,flag=0)
fileName=paste0("twitter",i4)
twit[i+1]<-list(readLines(fileName))
}

# Text Transformations to remove odd characters #
twit=lapply(twit,FUN=iconv, to='ASCII', sub=' ')
twit=lapply(twit,FUN= function(x) gsub("'{2}", " ",x))
twit=lapply(twit,FUN= function(x) gsub("[0-9]", " ",x))

# Create TDM using the function: #
myTDM<-makeTDM(twit)

# <<TermDocumentMatrix (terms: 11235, documents: 119)>>
# Non-/sparse entries: 1097831/239134
# Sparsity           : 18%
# Maximal term length: 22
# Weighting          : term frequency (tf)


# Build TDM with tri-grams.

triTDM <- makeTriTDM(twit)

## COMBINE ?? ##
# myTDM <- c(myTDM,newTDM)

# 2. Isolate bigrams and unigrams within trigrams 
#=============================================#

# Get total frequency in corpus of each trigram
library(slam)
unigramCount<-as.matrix(row_sums(myTDM))
gramCount<-as.matrix(row_sums(triTDM))

# Create dataframe frequency table
uniFreqTable <- data.frame(gram=dimnames(unigramCount)[[1]],count=unigramCount,stringsAsFactors=FALSE)
freqTable <- data.frame(gram=dimnames(gramCount)[[1]],count=gramCount,stringsAsFactors=FALSE)
# Split corpus trigrams up to words
words <- strsplit(freqTable$gram," ")

# Set first two words as an attribute, the trigram prediction query pair of words
freqTable$triquery <- sapply(words,FUN=function(x) paste(x[1],x[2]))

# Set each word of trigram as an attribute for future use
freqTable$one <- sapply(words,FUN=function(x) paste(x[1]))
freqTable$two <- sapply(words,FUN=function(x) paste(x[2]))
freqTable$three <- sapply(words,FUN=function(x) paste(x[3]))

# 3. INPUT MUNGING
#=============================================#
## INPUT MUNGING ##
# i. Take an input:
input<-"The guy in front of me just bought a pound of bacon, a bouquet, and a case of"

# ii. Perform Transformations.
input<-makeCorpus(input)
input<-as.character(input[[1]][1])

# iii. Reduce to last two words
input<-unlist(strsplit(input,"\\s+"))
two<-length(input)
one<-two-1
# iv. set querying bigrams and unigrams we will search for in trigrams and bigrams respectively
bigram<-paste(input[one],input[two])
unigram<-paste(input[two])

# 4. FIND PREDICTION MATCHES
#=============================================#

#TRIGRAMS:

# Find trigrams where first two words match and put in matches list
trimatches <- freqTable[freqTable$triquery == bigram,]
bimatch1 <- freqTable[freqTable$one == unigram,]
bimatch2 <- freqTable[freqTable$two == unigram,]

# Put these results in a frequency table and rank them as such.
matches<-c(trimatches$three,bimatch1$two,bimatch2$one)
matchCorpus<-makeCorpus(matches) # (Corpus(VectorSource(matches)) caused very similar terms to be considered separately like singular and plural)
matchTDM<-TermDocumentMatrix(matchCorpus)

# Get total frequency in prediction corpus of each prediction
predCount<-rowSums(as.matrix(matchTDM))

# Create dataframe frequency table
predFreq <- data.frame(gram=names(predCount),count=predCount,stringsAsFactors=FALSE)
predFreq<-predFreq[order(-predFreq$count),]

predFreq
gc()

# Bag of Words ? Problem is there are no associations there! it can only tell us the probability of a word in GENERAL. So... That is really not useful in terms of prediction EXCEPT to compare and choose the most likely of the trigram options perhaps.

