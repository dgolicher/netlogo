#d<-data.frame(area=rlnorm(100,1,2))
#area<-1:500
f<-function(area,halfarea){
  lambda<-log(2) / halfarea
  ext_prob<-100 * exp(- lambda * area)
  ext_prob
}
par(mfcol=c(2,2))
hist(d$area,col="grey",main="Areas")
hist(log(d$area),col="grey",main="Log areas")
hist(f(d$area,halfarea),col="grey",main="Extinction probs")
plot(area,f(area,halfarea),type="l",lwd=2,col=2,main="P_ext as function of area")
lines(c(halfarea,halfarea),c(0,50))
lines(c(halfarea,0),c(50,50))
grid()

