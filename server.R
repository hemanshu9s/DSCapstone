library(shiny)
options(shiny.trace = F)  # cahnge to T for trace
library(shinysky)

shinyServer(function(input, output) {
  library(tm)
  library(RWeka)
  library(data.table)
  library(SnowballC)
  library(stringr)
  
  # process.=cmpfun(process)
  # classify.=cmpfun(classify)
  # makeCorpus.=cmpfun(makeCorpus)
  
  ## FUNCTION DEFINITIONS ##
  # Make Corpus and do transformations
  makeCorpus<- function(x) {
    corpus<-Corpus(VectorSource(x))
    # corpus <- tm_map(corpus, stripWhitespace)
    corpus <- tm_map(corpus, content_transformer(tolower))
    # corpus <- tm_map(corpus, removeWords, stopwords("english"))
    corpus <- tm_map(corpus, stemDocument)
    corpus<- tm_map(corpus,removePunctuation)
    # corpus<- tm_map(corpus,removeNumbers)
    return(corpus)
  }
  
  process<- function(x) {
    x=gsub(",?", "", x)
    x=gsub("\\.{3,}", "", x)
    x=gsub("\\:", "", x)
    x=gsub("\\'", "", x)
    x=gsub("\\|", "", x)
    x=gsub("\\{", "", x)
    x=gsub("\\}", "", x)
    x<-strsplit(unlist(x),"[\\.]{1}")
    x<-strsplit(unlist(x),"\\?+")
    x<-strsplit(unlist(x),"\\!+") # Error: non-character argument?
    x<-strsplit(unlist(x),"\\-+")
    x<-strsplit(unlist(x),"\\(+")
    x<-strsplit(unlist(x),"\\)+")
    x<-strsplit(unlist(x),"\\\"")
    x<-gsub("^\\s+", "", unlist(x))
    x<-gsub("\\s+$", "", unlist(x))
    x<-gsub("\\s*~\\s*", " ", unlist(x))
    x<-gsub("\\/", " ", unlist(x))
    x<-gsub("\\+", " ", unlist(x))
    x<-gsub("it s ", "its ", unlist(x))
    x<-gsub("i m not", "im not", unlist(x))
    x<-gsub("i didn t", "i didnt", unlist(x))
    x<-gsub("i don t", "i dont", unlist(x))
    x<-gsub(" i m ", " im ", unlist(x))
    x=x[which(nchar(x)!=1)]
    x=x[which(nchar(x)!=0)]
  }
  
  classify=function(y,z,t){
    correct=0
    lapply(1:t,FUN=function(x){
      # loop through sentence making bigram and answer, 
      bigram=paste(z[x], z[x+1])
      answer=paste(z[x+2])
      # then check answer against predicted answer.
      # Get answer
      Xpred=data.table(y[grep(paste0("^",bigram," "),y$grams),][order(-counts)])  
      # isolate the answer from prediction table.
      Xpred=unlist(strsplit(Xpred[1]$grams,"\\s+"))
      Xpred=Xpred[length(Xpred)]
      # Test equality of prediction to actual and counter for the accuracy measure
      if(!is.na(Xpred)){
        if(Xpred==answer){correct=correct+1}  
        correct<<-correct
      }
    })
    accuracy = correct/length(z)
    return(accuracy)
  }
  
  getPred=function(x,a){
    # Take an input:
    test=x
    # transform as training set was (lowercase, stem, strip punctuation etc.)
    test=iconv(test, to='ASCII', sub=' ')
    test=process(test)
    test=paste0(test, collapse=" ")
    corpus<-makeCorpus(test)
    corpus=as.character(corpus[[1]][1])
    # Split by words:
    words<-unlist(strsplit(corpus,"\\s+"))
    Tfreq=afreq
    
    # Classify text (if 3 words or more)
    if(a==TRUE){
      if(length(words)>=3){
        
        total=length(words)-2
        #if(total>10){total=10}
        
        tfreq=readRDS("t.no4counts.RDS")
        bfreq=readRDS("b.no4counts.RDS")
        nfreq=readRDS("n.no4counts.RDS")
        
        b.acc=classify(bfreq,words,total)
        t.acc=classify(tfreq,words,total)
        n.acc=classify(nfreq,words,total)
        #a.acc=classify(afreq,words,total)
        # Select frequency table based on classification results.
        if(b.acc>t.acc && b.acc>n.acc && b.acc>a.acc){
          Tfreq=bfreq
        } else if(t.acc>b.acc && t.acc>n.acc && t.acc>a.acc){
          Tfreq=tfreq
        } else if(n.acc>b.acc && n.acc>t.acc && n.acc>a.acc){
          Tfreq=nfreq
        } else {
          Tfreq=afreq
        }
      }
    }
    
    # Isolate last two words of the sentence
    history=words[(length(words)-1):length(words)]
    nMin1=words[length(words)]
    history=paste(as.character(history),collapse=' ')
    histstring=str_replace_all(history, "[[:punct:]]", "?")
    # Make prediction list of matches:
    Tpred=data.table(Tfreq[grep(paste0("^",histstring," "),Tfreq$grams),][order(-counts)])
    # Isolate top prediction:
    pred=Tpred[1]$grams
    pred=unlist(strsplit(pred,"\\s+"))
    pred=pred[length(pred)]
    if(is.na(pred)){
      pred="the"
    }
    return(pred)
  }
  
  # Trigrams
  afreq=readRDS("ALL.no4counts.RDS")
  
  library(compiler)
  getPred.=cmpfun(getPred)
  
  # OUTPUT PREDICTION #
  
  output$prediction <- renderText({  
    as.character(getPred.(input$text,input$checkbox))
  })
})