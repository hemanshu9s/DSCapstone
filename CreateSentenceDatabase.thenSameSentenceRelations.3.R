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

twit<-fileMunge("twit100.txt")

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
####################################
#-
####################################
# load already created database:
library(filehash)
setwd("C:/Users/Michael/SkyDrive/Code/GitHub/DSCapstone/Coursera-SwiftKey/final/en_US")
db <- dbInit("t.ass", type="DB1")

# Get associations from a test set: #

# input test set
test<-fileMunge("test2.txt")
test.tdm<-makeTDM(test)

# Get list of sentence 1 terms:
test1<-dimnames(test.tdm[which(inspect(test.tdm[,1]!=0)),1])$Terms
# Fetch from DB frequent terms for first word of first sentence:
term=test1[2]

corrs=db[[term]]

# OK so corrs[[x]] gets just the number, 
# names(corrs)[x] gets the term.

####################################
####################################

inspect(test.tdm[,1])
which(inspect(test.tdm[,1]!=0))
inspect(test.tdm[which(inspect(test.tdm[,1]!=0)),1])
# OK that got me what I want now I want just the dimnames i guess.
length(dimnames(test.tdm[which(inspect(test.tdm[,1]!=0)),1])$Terms)
test1<-dimnames(test.tdm[which(inspect(test.tdm[,1]!=0)),1])$Terms
# What was the purpose of making TDM? Will I use frequency? Perhaps.
# So now i want to call up the file associations for each term, the more frequent may be given more weight later.
test1.db<-dbFetch(db,test1[2])
# 1. will need to deal with unfound terms like "ain't"
# 2. how do i get the correlation number? It does not appear to be here.

#########################################
#########################################
# Start the clock!
#ptm <- proc.time()

# Stop the clock
#proc.time() - ptm

#########################################
## Eliminate empties:
dbReorganize(db)
db <- dbInit("t.ass", type="DB1")
##
#########################################
#########################################
#########################################

#t.ass[grep("numeric\\(0\\)",as.character(t.ass))]=NULL 
#findAssocs(t.tdm,"all",0)

#{dbInsert(db,dimnames(t.ass[[x]])[[2]],dimnames(t.ass[[x]])[[1]][1:length(t.ass[[1]])])})
# OK now the problem is that they will overwrite.
# SO i do an exists check first.

lapply(t.ass,FUN=function(x)t.ass[dimnames(t.ass)==NULL]
which(dimnames(t.ass)==NULL)
t.ass[is.null(dimnames(t.ass))==0]

t.ass[grep("character\\(0\\)",as.character(dimnames(t.ass)))]=NULL 

if dimnames(t.ass[[x]])==

# okay.
#so now we can access like t.ass[word][rank of association] and get back the correlation. how do we get the word back?
# dimnames(t.ass[[1]])[[1]] gives the matches, dimnames(t.ass[[x]][[2]]) gives the word.
# dimnames(t.ass[[1]])[[1]][x] x is each word as a character.
# dimnames(t.ass[[1]])[[1]][1:length(t.ass[[1]])] gives all matches as characters....
# insert each unit of t.ass where [[2]] is the word, [[]]
dbInsert(db,dimnames(t.ass[[1]])[[2]],dimnames(t.ass[[1]])[[1]][1:length(t.ass[[1]])])
# yay above worked. OK we now have a basic model for making this database.
#Next, expand it to all in our test set.

# OK this worked to a point... but hit a null... at 7?
# OK i need to remove nulls first then.
test<-as.character(t.ass)
grep("numeric\\(0\\)",as.character(t.ass))
t.ass[grep("numeric\\(0\\)",as.character(t.ass))]=NULL #yay
grep("numeric\\(0\\)",as.character(t.ass))

output[which(nchar(unlist(unlist(output)))==1)]=NULL
Filter(function(x) identical(character(0),x),t.ass)
#
dbInsert(db,dimnames(t.ass[[2]])[[2]],dimnames(t.ass[[2]])[[1]][1:length(t.ass[[1]])])

dimnames(t.ass[[]])[[2]]
# Stop the clock
proc.time() - ptm
#########################################
dbInsert(db,"t","Test")
	#[[1:length(t.ass[[1]])]])

dbInsert(db, "a", c("test", 0.50))

dbInsert(db, "a", c("test", 0.50))

#Insert data to database
dbInsert(db, "a", rnorm(100))
# Here we have associated with the key “a” 100 standard normal random variates. We can retrieve those values with dbFetch.
value <- dbFetch(db, "a")
#dbDelete(db, "a")
#dbList(db)

##########################
# REFERENCE:
# grep to find a quotation mark: grep("\\\"",twit4)
# all this time my problem has been the original reference duhr! (list, not char)
# If you want to just get the set of values that are not "": 
# twit12[twit12 != ""] 
# which(nchar(twit12)==1)
# which(nchar(twit12)==0)

# this did not work: 
# twit12<-twit10[unlist(twit11) != ""] 

# dimnames(t.tdm)$Terms 

# library(filehash)
# filehashOption("DB1")
# dbCreate("t.ass")
# db <- dbInit("t.ass", type="DB1")
# lapply(1:length(t.ass),FUN=function(x){
# if(dbExists(db, dimnames(t.ass[[x]])[[2]])==TRUE){temp<-dbFetch(db,dimnames(t.ass[[x]])[[2]])
# dbInsert(db,dimnames(t.ass[[x]])[[2]],c(dimnames(t.ass[[x]])[[1]][1:length(t.ass[[1]])],temp))
# }else{
# dbInsert(db,dimnames(t.ass[[x]])[[2]],dimnames(t.ass[[x]])[[1]][1:length(t.ass[[1]])])
# }})
# # Now I want to store the correlation factor, not just the word. Can I do this with lists? or is there a Dictionary like function? or Data frames?
# # First let's test it with one word "ain't" well that won't work it's not in the corpus. So but then. Oh but we are testing made up data first.
# dbInsert(db,"ain't",c(dog=.50,cat=.75))
# dbInsert(db,"ain't",c(.20,.3))
# dbInsert(db,"ain't",names("aint")<-c("dog","cat"))
# names(db["ain't"])=c("dog","cat")
# # THIS worked:
# names(db$"ain't")=c("dog","cat")
# db$"ain't"