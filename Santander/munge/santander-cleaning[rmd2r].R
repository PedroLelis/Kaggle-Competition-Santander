#' ---	
#' title: "Detailed Data Cleaning/Visualization"	
#' output: html_document	
#' ---	
#' 	
#' 	
knitr::opts_chunk$set(echo = TRUE, message=FALSE)	
#' 	
#' 	
#' The goal of this competition is to predict which new Santander products, if any, a customer will purchase in the following month. Here, I will do some data cleaning, adjust some features, and do some visualization to get a sense of what features might be important predictors. I won't be building a predictive model in this kernel, but I hope this gives you some insight/ideas and gets you excited to build your own model.	
#' 	
#' Let's get to it	
#' 	
library(data.table)	
library(dplyr)	
library(tidyr)	
library(lubridate)	
library(ggplot2)	
library(fasttime)	
#' 	
#' 	
#' #### ggplot2 Theme Trick	
#' A cool trick to avoid repetitive code in `ggplot2` is to save/reuse your own theme. I'll build one here and use it throughout.	
#' 	
my_theme <- theme_bw() +	
  theme(axis.title=element_text(size=24),	
        plot.title=element_text(size=36),	
        axis.text =element_text(size=16))	
	
my_theme_dark <- theme_dark() +	
  theme(axis.title=element_text(size=24),	
        plot.title=element_text(size=36),	
        axis.text =element_text(size=16))	
	
#' 	
#' 	
#' ## First Glance	
#' Limit the number of rows read in to avoid memory crashes with the kernel	
#' 	
#setwd("~/kaggle/competition-santander/")	
set.seed(1)	
df   <- (fread("train_ver2.csv"))	
test <- (fread("test_ver2.csv"))	
features <- names(df)[grepl("ind_+.*ult.*",names(df))]	
#' 	
#' 	
#' I will create a label for each product and month that indicates whether a customer added, dropped or maintained that service in that billing cycle. I will do this by assigning a numeric id to each unique time stamp, and then matching each entry with the one from the previous month. The difference in the indicator value for each product then gives the desired value.  	
#' A cool trick to turn dates into unique id numbers is to use `as.numeric(factor(...))`. Make sure to order them chronologically first.	
#' 	
#' 	
df                     <- df %>% arrange(fecha_dato) %>% as.data.table()	
df$month.id            <- as.numeric(factor((df$fecha_dato)))	
df$month.previous.id   <- df$month.id - 1	
test$month.id          <- max(df$month.id) + 1	
test$month.previous.id <- max(df$month.id)	
	
# Test data will contain the status of products for the previous month, which is a feature. The training data currently contains the status of products as labels, and will later be joined to the previous month to get the previous month's ownership as a feature. I choose to do it in this order so that the train/test data can be cleaned together and then split. It's just for convenience.	
test <- merge(test,df[,names(df) %in% c(features,"ncodpers","month.id"),with=FALSE],by.x=c("ncodpers","month.previous.id"),by.y=c("ncodpers","month.id"),all.x=TRUE)	
	
df <- rbind(df,test)	
	
#' 	
#' 	
#' 	
#' We have a number of demographics for each individual as well as the products they currently own. To make a test set, I will separate the last month from this training data, and create a feature that indicates whether or not a product was newly purchased. First convert the dates. There's `fecha_dato`, the row-identifier date, and `fecha_alta`, the date that the customer joined.	
#' 	
#' 	
df[,fecha_dato:=fastPOSIXct(fecha_dato)]	
df[,fecha_alta:=fastPOSIXct(fecha_alta)]	
# unique(df$fecha_dato)	
#' 	
#' 	
#' I printed the values just to double check the dates were in standard Year-Month-Day format. I expect that customers will be more likely to buy products at certain months of the year (Christmas bonuses?), so let's add a month column. I don't think the month that they joined matters, so just do it for one.	
#' 	
df$month <- month(df$fecha_dato)	
#' 	
#' 	
#' Are there any columns missing values?	
#' 	
sapply(df,function(x)any(is.na(x)))	
#' 	
#' 	
#' Definitely. Onto data cleaning.	
#' 	
#' ##Data Cleaning	
#' 	
#' Going down the list, start with `age`	
#' 	
# ggplot(data=df,aes(x=age)) + 	
#   geom_bar(alpha=0.75,fill="tomato",color="black") +	
#   xlim(c(18,100)) +	
#   ggtitle("Age Distribution") + 	
#   my_theme	
#' 	
#' 	
#' 	
#' In addition to NA, there are people with very small and very high ages.	
#' It's also interesting that the distribution is bimodal. There are a large number of university aged students, and then another peak around middle-age. Let's separate the distribution and move the outliers to the mean of the closest one.	
#' 	
# df$age[(df$age < 18)] <- median(df$age[(df$age >= 18) & (df$age <=30)],na.rm=TRUE)	
# df$age[(df$age > 100)] <- median(df$age[(df$age >= 30) & (df$age <=100)],na.rm=TRUE)	
# df$age[is.na(df$age)] <- median(df$age,na.rm=TRUE)	
	
	
	
age.change  <- df[month.id>6,.(age,month,month.id,age.diff=c(0,diff(age))),by="ncodpers"]	
age.change  <- age.change[age.diff==1]	
age.change  <- age.change[!duplicated(age.change$ncodpers)]	
setkey(df,ncodpers)	
df <- merge(df,age.change[,.(ncodpers,birthday.month=month)],by=c("ncodpers"),all.x=TRUE,sort=FALSE)	
df$birthday.month[is.na(df$birthday.month)] <- 7 # July is the only month we don't get to check for increment so if there is no update then use it	
df$age[df$birthday.month <= 7 & df$month.id<df$birthday.month] <- df$age[df$birthday.month <= 7 & df$month.id<df$birthday.month]  - 1 # correct ages in the first 6 months	
	
df$age[is.na(df$age)] <- -1	
	
# age.change$birthday <- age.change$month[age.change$age.diff==1]	
# age.change$birthday <- ave(age.change$month,age.change$ncodpers,FUN=function(x,y)return(x[y==1]),y=age.change$age.diff)	
df$age <- round(df$age)	
#' 	
#' 	
#' 	
#' 	
df <- as.data.frame(df)	
#' 	
#' 	
#' 	
# ggplot(data=df,aes(x=age)) + 	
#   geom_bar(alpha=0.75,fill="tomato",color="black") +	
#   xlim(c(18,100)) + 	
#   ggtitle("Age Distribution") + 	
#   my_theme	
#' 	
#' 	
#' Looks better.  	
#' 	
#' Next `ind_nuevo`, which indicates whether a customer is new or not. How many missing values are there?	
#' 	
sum(is.na(df$ind_nuevo))	
#' 	
#' 	
#' Let's see if we can fill in missing values by looking how many months of history these customers have.	
#' 	
months.active <- df[is.na(df$ind_nuevo),] %>%	
  group_by(ncodpers) %>%	
  summarise(months.active=n())  %>%	
  select(months.active)	
max(months.active)	
#' 	
#' 	
#' Looks like these are all new customers, so replace accordingly.	
#' 	
df$ind_nuevo[is.na(df$ind_nuevo)] <- 1 	
#' 	
#' 	
#' Now, `antiguedad`	
#' 	
sum(is.na(df$antiguedad))	
#' 	
#' 	
#' That number again. Probably the same people that we just determined were new customers. Double check.	
#' 	
summary(df[is.na(df$antiguedad),]%>%select(ind_nuevo))	
#' 	
#' 	
#' Yup, same people. Let's give them minimum seniority.	
#' 	
#' 	
	
# For the cleaning version I am removing these entries	
# df <- df[(!is.na(df$antiguedad)) | df$month.id==max(df$month.id),]	
# df$antiguedad[is.na(df$antiguedad)] <- min(df$antiguedad,na.rm=TRUE)	
	
	
new.antiguedad <- df %>% 	
  dplyr::select(ncodpers,month.id,antiguedad) %>%	
  dplyr::group_by(ncodpers) %>%	
  dplyr::mutate(antiguedad=min(antiguedad,na.rm=T) + month.id - 6) %>%	
  ungroup() %>%	
  dplyr::arrange(ncodpers) %>%	
  dplyr::select(antiguedad)	
df <- df %>%	
  arrange(ncodpers)	
df$antiguedad <- new.antiguedad$antiguedad	
	
df$antiguedad[df$antiguedad<0] <- -1	
	
elapsed.months <- function(end_date, start_date) {	
  12 * (year(end_date) - year(start_date)) + (month(end_date) - month(start_date))	
}	
recalculated.antiguedad <- elapsed.months(df$fecha_dato,df$fecha_alta)	
df$antiguedad[!is.na(df$fecha_alta)] <- recalculated.antiguedad[!is.na(df$fecha_alta)]	
df$ind_nuevo <- ifelse(df$antiguedad<=6,1,0)	
#' 	
#' 	
#' 	
#' Some entries don't have the date they joined the company. Just give them something in the middle of the pack	
#' 	
df$fecha_alta[is.na(df$fecha_alta)] <- median(df$fecha_alta,na.rm=TRUE)	
#' 	
#' 	
#' 	
#' Next is `indrel`, which indicates:	
#' 	
#' > 1 (First/Primary), 99 (Primary customer during the month but not at the end of the month)	
#' 	
#' This sounds like a promising feature. I'm not sure if primary status is something the customer chooses or the company assigns, but either way it seems intuitive that customers who are dropping down are likely to have different purchasing behaviors than others.	
#' 	
#' 	
table(df$indrel)	
#' 	
#' 	
#' Fill in missing with the more common status.	
#' 	
#' 	
df$indrel[is.na(df$indrel)] <- 1	
#' 	
#' 	
#' > tipodom	- Addres type. 1, primary address	
#'  cod_prov	- Province code (customer's address)	
#' 	
#' `tipodom` doesn't seem to be useful, and the province code is not needed becaue the name of the province exists in `nomprov`.	
#' 	
df <- df %>% select(-tipodom,-cod_prov)	
#' 	
#' 	
#' Quick check back to see how we are doing on missing values	
#' 	
sapply(df,function(x)any(is.na(x)))	
#' 	
#' 	
#' Getting closer.	
#' 	
#' 	
sum(is.na(df$ind_actividad_cliente))	
#' 	
#' By now you've probably noticed that this number keeps popping up. A handful of the entries are just bad, and should probably just be excluded from the model. But for now I will just clean/keep them.  	
#' 	
#' Just a couple more features.	
#' 	
#' 	
df$ind_actividad_cliente[is.na(df$ind_actividad_cliente)] <- median(df$ind_actividad_cliente,na.rm=TRUE)	
#' 	
#' 	
#' 	
unique(df$nomprov)	
#' 	
#' 	
#' There's some rows missing a city that I'll relabel	
#' 	
#' 	
df$nomprov[df$nomprov==""] <- "UNKNOWN"	
#' 	
#' 	
#' 	
#' Now for gross income, aka `renta`	
#' 	
sum(is.na(df$renta))	
#' 	
#' 	
#' Here is a feature that is missing a lot of values. Rather than just filling them in with a median, it's probably more accurate to break it down region by region. To that end, let's take a look at the median income by region, and in the spirit of the competition let's color it like the Spanish flag.	
#' 	
#' 	
# df %>%	
#   filter(!is.na(renta)) %>%	
#   group_by(nomprov) %>%	
#   summarise(med.income = median(renta)) %>%	
#   arrange(med.income) %>%	
#   mutate(city=factor(nomprov,levels=nomprov)) %>%	
#   ggplot(aes(x=city,y=med.income)) + 	
#   geom_point(color="#c60b1e") + 	
#   guides(color=FALSE) + 	
#   xlab("City") +	
#   ylab("Median Income") +  	
#   my_theme + 	
#   theme(axis.text.x=element_blank(), axis.ticks = element_blank()) + 	
#   geom_text(aes(x=city,y=med.income,label=city),angle=90,hjust=-.25) +	
#   theme(plot.background=element_rect(fill="#c60b1e"),	
#         panel.background=element_rect(fill="#ffc400"),	
#         panel.grid =element_blank(),	
#         axis.title =element_text(color="#ffc400"),	
#         axis.text  =element_text(color="#ffc400"),	
#         plot.title =element_text(color="#ffc400")) +	
#   ylim(c(60000,180000)) +	
# 	
# 	
#   ggtitle("Income Distribution by City")	
#' 	
#' 	
#' 	
#' There's a lot of variation, so I think assigning missing incomes by providence is a good idea. This code gets kind of confusing in a nested SQL statement kind of way, but the idea is to first group the data by city, and reduce to get the median. This intermediate data frame is joined by the original city names to expand the aggregated median incomes, ordered so that there is a 1-to-1 mapping between the rows, and finally the missing values are replaced.	
#' 	
#' 	
# new.incomes <-df %>%	
#   select(nomprov) %>%	
#   merge(df %>%	
#   group_by(nomprov) %>%	
#   dplyr::summarise(med.income=median(renta,na.rm=TRUE)),by="nomprov") %>%	
#   select(nomprov,med.income) %>%	
#   arrange(nomprov)	
# df <- arrange(df,nomprov)	
# df$renta[is.na(df$renta)] <- new.incomes$med.income[is.na(df$renta)]	
# rm(new.incomes)	
# 	
# df$renta[is.na(df$renta)] <- median(df$renta,na.rm=TRUE)	
df$renta[is.na(df$renta)] <- -1	
#' 	
#' 	
#' The last line is to account for any values that are still missing. For example, it seems every entry from Alava has NA for `renta`.	
#' 	
#' The only remaining missing value are for features	
#' 	
sum(is.na(df$ind_nomina_ult1))	
#' 	
#' 	
#' I could try to fill in missing values for products by looking at previous months, but since it's such a small number of values for now I'll take the cheap way out.	
#' 	
#' 	
df[is.na(df)] <- 0	
#' 	
#' 	
#' Now we have taken care of all the missing values. There's also a bunch of character columns that can contain empty strings, so we need to go through them. For the most part, entries with empty strings will be converted to an unknown category.	
#' 	
#' 	
str(df)	
#' 	
#' 	
#' 	
char.cols <- names(df)[sapply(df,is.character)]	
# char.cols <- char.cols[!char.cols %in% c("fecha_dato","fecha_alta")] #ignore dates for this purpose	
for (name in char.cols){	
  print(sprintf("Unique values for %s:", name))	
  print(unique(df[[name]]))	
  }	
#' 	
#' 	
#' Okay, based on that and the definitions of each variable, I will fill the empty strings either with the most common value or create an unknown category based on what I think makes more sense.	
#' 	
df$indfall[df$indfall==""]               <- "N"	
df$tiprel_1mes[df$tiprel_1mes==""]       <- "A"	
df$indrel_1mes[df$indrel_1mes==""] <- "1"	
df$indrel_1mes[df$indrel_1mes=="P"] <- "5"	
df$indrel_1mes <- as.factor(as.integer(df$indrel_1mes))	
	
df$pais_residencia[df$pais_residencia==""] <- "UNKNOWN"	
df$sexo[df$sexo==""]                       <- "UNKNOWN"	
df$ult_fec_cli_1t[df$ult_fec_cli_1t==""]   <- "UNKNOWN"	
df$ind_empleado[df$ind_empleado==""]       <- "UNKNOWN"	
df$indext[df$indext==""]                   <- "UNKNOWN"	
df$indresi[df$indresi==""]                 <- "UNKNOWN"	
df$conyuemp[df$conyuemp==""]               <- "UNKNOWN"	
df$segmento[df$segmento==""]               <- "UNKNOWN"	
	
#' 	
#' 	
#' 	
#' Convert all the features to numeric dummy indicators (you'll see why in a second), and we're done cleaning	
#' 	
features <- grepl("ind_+.*ult.*",names(df))	
df[,features] <- lapply(df[,features],function(x)as.integer(round(x)))	
#' 	
#' 	
#' 	
source('project/Santander/lib/create-lag-feature.R')	
df <- as.data.table(df)	
df <- create.lag.feature(df,'ind_actividad_cliente',1:11,na.fill=0)	
df[,last.age:=lag(age),by="ncodpers"]	
df$turned.adult <- ifelse(df$age==20 & df$last.age==19,1,0)	
df <- as.data.frame(df)	
#' 	
#' 	
#' 	
#' 	
features <- names(df)[grepl("ind_+.*ult.*",names(df))]	
	
test <- df %>%	
  filter(month.id==max(df$month.id))	
df <- df %>%	
  filter(month.id<max(df$month.id))	
write.csv(df,"cleaned_train.csv",row.names=FALSE)	
write.csv(test,"cleaned_test.csv",row.names=FALSE)	
#' 	
#' 	
#' 	
#' 	
