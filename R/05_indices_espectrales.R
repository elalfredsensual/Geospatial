pacman::p_load(tidyverse, rgee, sf, raster)
#ee_install()

ee_Initialize(drive = T)

# defino una region de interes ----
roi <- 
  c(-70.915374, -33.8464671) %>%  # laguna aculeo
  st_point(dim = "XYZ") %>% 
  st_buffer(dist = 0.1) %>% 
  sf_as_ee()

# captura de imagenes satelitales ----

# identifico posibles fechas de imagenes del LS8
disponible <- ee$ImageCollection('LANDSAT/LC08/C01/T1_TOA')$
  filterDate('2013-07-01','2014-07-10')$
  filterBounds(roi)$
  filterMetadata('CLOUD_COVER','less_than', 5)

# ordeno las fechas
df_disponible <- ee_get_date_ic(disponible)%>%
  arrange(time_start)

# extraigo la primera
escena <- df_disponible$id[1]

# defino las bandas que me interesa extraer
l8_bands <- ee$Image(escena)$select(c("B1", "B2", "B3", "B4", 
                                      "B5", "B6", "B7", "B9"))
# B1: Aerosol, B2: Blue, B3: Green, B4: Red
# B5: NIR, B6: SWIR 1, B7: SWIR 2, B9: Cirrus

# extraigo imagenes satelitales 
l8_img <- ee_as_raster(
  image = l8_bands,
  region = roi$bounds(),
  scale = 30)

png(file="Figuras/aculeo_plot.png", width=500, height=600)
plotRGB(l8_img, r=4, g=3, b=2, stretch = "lin")
dev.off()

# indices espectrales ----

# llamo funciones
source("R/indices.R")

veg <- NVDI(l8_img)

plot(veg)

# listo funciones
funs <- lsf.str()

for(i in 1:length(funs)){
  png(file=paste0("Figuras/",funs[i],"_plot.png"), width=500, height=600)
  plot(do.call(funs[i], list(l8_img)))
  dev.off()
}

# analisis aculeo en el tiempo ----
analisis_aculeo <- function(anio){
  disponible <- ee$ImageCollection('LANDSAT/LC08/C01/T1_TOA')$
    filterDate(paste0(anio,'-07-01'),paste0(anio,'-07-30'))$
    filterBounds(roi)$
    filterMetadata('CLOUD_COVER','less_than', 10)
  
  df_disponible <- ee_get_date_ic(disponible)%>%
    arrange(time_start)
  
  # extraigo la primera
  escena <- df_disponible$id[1]
  
  # defino las bandas que me interesa extraer para el NDWI
  l8_bands <- ee$Image(escena)$select(c("B2", "B3", "B4", "B5"))
  # B1: Aerosol, B2: Blue, B3: Green, B4: Red
  # B5: NIR, B6: SWIR 1, B7: SWIR 2, B9: Cirrus
  
  # extraigo imagenes satelitales 
  l8_img <- ee_as_raster(
    image = l8_bands,
    region = roi$bounds(),
    scale = 30)
  
  # extraigo valores de agua
  agua <- calc(NDWI(l8_img), fun = function(x) ifelse(x <= 0.2, NA, x))
  
  # guardo plot
  png(file=paste0("Figuras/aculeo_anio",anio,".png"), width=500, height=600)
  plotRGB(l8_img, r=3, g=2, b=1, stretch = "lin")
  plot(agua, add = TRUE)
  dev.off()
}

analisis_aculeo(2014)

purrr::map(2013:2021, analisis_aculeo)
