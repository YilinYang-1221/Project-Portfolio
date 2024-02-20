#HW3 - Yilin Yang

# Set working directory
setwd("/Users/yilin/Desktop/Retail Analytics/R codes")
# Read the data 
energy_bars <- read.csv("/Users/yilin/Desktop/Retail Analytics/R codes/energy_bars.csv")
View(energy_bars)

#1a
attach(energy_bars)
summary(energy_bars)

#1b
par(mar = c(5, 4, 4, 4) + 0.3)  # Leave space for Z axis
plot(weeknum, price_zone, "l", col = "blue", lty =3) # First plot
par(new = TRUE) # Allow a second plot on the same graph
plot(weeknum, units_zone, "l",  ylim = c(0,4000), 
     axes = FALSE, col="red", bty = "n", xlab = "", ylab = "") # Second plot
axis(side=4, at = pretty(range(units_zone))) # Set Z axis
mtext("units_zone", side=4, line=3) # Set legend for Z axis
legend("topright",legend=c("Zoneperfect price","Zoneperfect quantity"), 
       col=c("blue","red"), lty=c(3,1), ncol=1,  box.lty=0)

#1c
pairs(data.frame(price_zone, units_zone))
#test the correlation between two variables
cor.test(price_zone, units_zone)

#1d
ln_p_zone <- log(price_zone)
ln_q_zone <- log(units_zone)
pairs(data.frame(ln_p_zone,ln_q_zone))
cor.test(ln_p_zone,ln_q_zone)


#2a
View(energy_bars)
lm1 <- lm(units_zone ~ price_zone, data = energy_bars)
summary(lm1)

#2b
lm2 <- lm(ln_q_zone ~ ln_p_zone, data = energy_bars)
summary(lm2)


#3a & 3b
# Generate dummy variables for Zoneperfect's sales promotion
prom_z_maj <- ifelse(sale_zone == 1, 1,0)
prom_z_min <- ifelse(sale_zone == 2, 1,0)
lm3 <- lm(ln_q_zone ~ ln_p_zone + prom_z_maj + prom_z_min, data = energy_bars)
summary(lm3)

#3c
# Create year dummies
year_2006 <- ifelse(year==2006,1,0)
year_2007 <- ifelse(year==2007,1,0)
# Generate log prices of competitors
ln_p_clif <- log(price_clif)
ln_q_clif <- log(units_clif)
ln_p_luna <- log(price_luna)
ln_q_luna <- log(units_luna)
# Generate dummy variables for Clif and Luna's sales promotion
prom_c_maj <- ifelse(sale_clif == 1, 1,0)
prom_c_min <- ifelse(sale_clif == 2, 1,0)
prom_l_maj <- ifelse(sale_luna == 1, 1,0)
prom_l_min <- ifelse(sale_luna == 2, 1,0)

# Construct linear model
lm4 <- lm(ln_q_zone ~ ln_p_zone + prom_z_maj + prom_z_min
          + year_2006 + year_2006
          + ln_p_clif + ln_q_clif + ln_p_luna + ln_q_luna
          + prom_c_maj + prom_c_min + prom_l_maj + prom_l_min, data = energy_bars)

summary(lm4)
