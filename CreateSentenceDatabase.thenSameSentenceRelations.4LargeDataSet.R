# Start the clock!
ptm <- proc.time()
##########################

# SETUP #
setwd("C:/Users/Michael/SkyDrive/Code/GitHub/DSCapstone/Coursera-SwiftKey/final/en_US")
options("max.print"=1000000)

# Modify fileMunge to leave sentence separators intact and only take 10 lines for now.

fileMunge<- function(x) {
text<-readLines(x)
totalLines=length(text)
chunkSize=20000
chunks=totalLines/chunkSize
remainder = chunks %% 1
wholeChunks = chunks-remainder
# initialize list
output=list()
# break file into chunks 
i=1
line=1
while (i<=wholeChunks){
end=line+chunkSize-1
output[[i]]<-text[line:end]
line=end+1
i=i+1
}
output[[i]]<-text[line:totalLines]
# Text Transformations to remove odd characters #
# CONVERT TO ASCII
output=lapply(output,FUN=iconv, to='ASCII', sub=' ')
# replace APOSTROPHES OF 2 OR MORE with space - WHY??? that never happens..
	# output=lapply(output,FUN= function(x) gsub("'{2}", " ",x))
# Replace numbers with spaces... not sure why to do that yet either.
	# output=lapply(output,FUN= function(x) gsub("[0-9]", " ",x))
# Erase commas.
output=lapply(output,FUN=function(x) gsub(",?", "", x))
# Erase ellipsis
output=lapply(output,FUN=function(x) gsub("\\.{3,}", "", x))
# Erase colon
output=lapply(output,FUN=function(x) gsub("\\:", "", x))
##### SENTENCE SPLITTING AND CLEANUP
# Split into sentences only on single periods or any amount of question marks or exclamation marks and -
output<-strsplit(output[[1]],"[\\.]{1}")
output<-strsplit(unlist(output),"\\?+")
output<-strsplit(unlist(output),"\\!+")
output<-strsplit(unlist(output),"\\-+")
# Split also on parentheses
output<-strsplit(unlist(output),"\\(+")
output<-strsplit(unlist(output),"\\)+")
# split also on quotation marks
output<-strsplit(unlist(output),"\\\"")
# remove spaces at start and end of sentences:
output<-lapply(output,FUN=function(x) gsub("^\\s+", "", x))
output<-lapply(output,FUN=function(x) gsub("\\s+$", "", x))
# Replace ~ and any whitespace around with just one space
output<-lapply(output,FUN=function(x) gsub("\\s*~\\s*", " ", x))
# Eliminate empty and single letter values (more?)
output[which(nchar(unlist(unlist(output)))==1)]=NULL
output[which(nchar(unlist(unlist(output)))==0)]=NULL
output=unlist(output)
}

twit<-fileMunge("en_US.twitter.txt")

########################## 
# END SENTENCE CREATION  #
##########################

########################## 
# BUILD ASSOCIATED WORDS DATABASE (ALL FOUND IN SAME SENTENCE)  #
##########################
# Further Transformations
# lower and stem, TDM
library(tm)
makeTDM <- function(x) {
corpus<-Corpus(VectorSource(x))
corpus <- tm_map(corpus, content_transformer(tolower))
corpus <- tm_map(corpus, stemDocument)
tdm<- TermDocumentMatrix(corpus)
#tdm<-removeSparseTerms(tdm,0.97)
return(tdm)}

t.tdm <- makeTDM(twit)

#########################################
# Create a matrix of associations. or just straight to db.
# this is the slowest part... do i need it?
t.ass<-lapply(dimnames(t.tdm)$Terms,FUN=function(x){findAssocs(t.tdm,x,0)})
#clean out nulls. NOTE - why do i have stuff separated by periods though??
t.ass[which(lapply(1:length(t.ass),FUN=function(x){is.null(dimnames(t.ass[[x]]))==1})==TRUE)]=NULL
#########################################
# Create filehash database

# So, I want to re-write my lapply function so that it stores the numbers first, then the names.
# hm what is the 2 here for? Ah, 2 is the key word, 1 are the values.
# so names will be dimnames(t.ass[[x]][1])
# values will be: t.ass[[1]][1:length(t.ass[[1]])]
library("filehash")
filehashOption("DB1")
dbCreate("t.ass")
db <- dbInit("t.ass", type="DB1")
x=2
lapply(1:length(t.ass),FUN=function(x){
key=dimnames(t.ass[[x]])[[2]]
new=t.ass[[x]][1:length(t.ass[[x]])]
names(new)=dimnames(t.ass[[x]])[[1]]
# [3] Error in names(new) = dimnames(t.ass[[x]])[[1]] : 'names' attribute [8] must be the same length as the vector [5]
if(dbExists(db,key)==TRUE)
{
existing=db[[key]]
db[[key]]=c(new,existing)
}
else
{
db[[key]]=new
}
})

# Stop the clock
proc.time() - ptm
