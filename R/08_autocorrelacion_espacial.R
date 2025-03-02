# Cargar Librerias
pacman::p_load(tidyverse, sf, MASS, gstat, raster, 
               spdep, spatialreg, patchwork)


# ***************************
# Cargar y ordenar datos ----


# manzanas las condes
mz_lc <- read_rds("data/MBHT_LC.rds") 

# verificamos proyeccion
st_crs(mz_lc)

# visualizamos
ggplot() +
  geom_sf(data = mz_lc, aes(fill=ibt)) 

# exploramos los valores de ingresos
mz_lc$ibt
hist(mz_lc$ibt, main=NULL)
boxplot(mz_lc$ibt, horizontal = TRUE)
mz_lc$ibt %>% summary()


# variograma ----

# manzanas en version puntos
mz_point <- mz_lc %>%
  st_centroid()

formMod <- ibt ~ 1
variog_empirico <- variogram(formMod, mz_point, cutoff=3000)

variog_teorico <- fit.variogram(variog_empirico, 
                                model = vgm(model  = "Exp", nugget = 0.8))

plot(variog_teorico, cutoff = 3000, add=TRUE)
plot(variog_empirico)


## moran ----


# generamos lista de vecinos
nb <- poly2nb(mz_lc, queen=TRUE)

# generamos pesos a partir de los vecinos
lw <- nb2listw(nb, style="W", zero.policy=TRUE)

plot(lw, coords = st_coordinates(st_centroid(mz_lc)), col='red')

# resolvermos de 3 maneras: radio, buffer y knn

# buffer
poly_buff <- 
  mz_lc %>% 
  st_buffer(dist=50) %>% 
  st_cast("MULTIPOLYGON")

buff_nb <- mat2listw(st_overlaps(poly_buff, sparse=FALSE))

plot(buff_nb, coords = st_coordinates(st_centroid(mz_lc)), col='red')


# knn
nvec <- 12
knn_nb <- spdep::nb2listw(neighbours = spdep::knn2nb(
  knn = spdep::knearneigh( x = mz_point, k = nvec, longlat = F)),
  style = "W")

plot(knn_nb, coords = st_coordinates(st_centroid(mz_lc)), col='red')

# radio
radius <- 200
# calcula matriz de distancias
dist_mat <- 
  st_distance(mz_point, mz_point) 

# calcula el inverso y asigna 0 en la diagonal
distancias.inv <- 1/dist_mat
diag(distancias.inv) <- 0

# asigna 0 si distancia es mayor al radio
distancias.inv[as.numeric(dist_mat) > radius] <- 0

# matriz de pesos
sp_w <- matrix(as.numeric(distancias.inv), nrow =  nrow(distancias.inv))

# lista de pesos
rad_nb <- mat2listw(sp_w)

plot(rad_nb, coords = st_coordinates(st_centroid(mz_lc)), col='red')


# calculamos el indice global de moran
I <- moran(mz_lc$ibt, knn_nb, length(knn_nb), Szero(knn_nb))
I

# calculamos el pvalue del indice
moran.test(mz_lc$ibt, knn_nb, alternative="greater")

# Moran local y significancia

lmoran <- localmoran(mz_lc$ibt, knn_nb) %>% as.data.frame()

# generamos lo cuadrantes de moran
matrix <- data.frame(value = ifelse(mz_lc$ibt > mean(mz_lc$ibt), "H", "L"),
                     correlation = ifelse(lmoran$Ii > mean(lmoran$Ii),"H","L"),
                     significance = lmoran$`Pr(z != E(Ii))`) %>% 
  mutate(cuadrant = ifelse(significance < 0.1,paste0(value,correlation),NA))

# traspasamos variable a objeto original
mz_lc$cuadrant <- matrix$cuadrant

ggplot() +
  geom_sf(data=mz_lc, aes(fill=cuadrant))
