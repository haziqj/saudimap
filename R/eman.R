# Thanks to Eman Kabbas
library(sf)
library(terra)
library(ggplot2)

# ---- Download & read GADM SAU shapefiles (ADM1 & ADM2) ----
gadm_url <- "https://geodata.ucdavis.edu/gadm/gadm4.1/shp/gadm41_SAU_shp.zip"
zipfile  <- tempfile(fileext = ".zip")
download.file(gadm_url, zipfile, mode = "wb")

unz_dir <- tempfile(); dir.create(unz_dir)
unzip(zipfile, exdir = unz_dir)

adm1_path <- list.files(unz_dir, pattern = "gadm41_SAU_1\\.shp$", full.names = TRUE)  # Regions
adm2_path <- list.files(unz_dir, pattern = "gadm41_SAU_2\\.shp$", full.names = TRUE)  # Governorates

adm1 <- st_as_sf(vect(adm1_path))  # sf
adm2 <- st_as_sf(vect(adm2_path))  # sf

# Quick plots
plot(adm1["NAME_1"])
plot(adm2["NAME_2"])

# ggplot versions
ggplot(adm1) + geom_sf(fill = NA) +
  geom_sf_text(aes(label = NAME_1), size = 3, check_overlap = TRUE) +
  labs(title = "Saudi Arabia – Regions (ADM1)")

ggplot(adm2) + geom_sf(fill = NA) +
  geom_sf_text(aes(label = NAME_2), size = 2, check_overlap = TRUE) +
  labs(title = "Saudi Arabia – Governorates (ADM2)")

# # Optional: save for later st_read()
# st_write(adm1, "~/Arafat_Monthly/ksa_admin.gpkg", layer = "adm1_regions", delete_layer = TRUE)
# st_write(adm2, "~/Arafat_Monthly/ksa_admin.gpkg", layer = "adm2_governorates", delete_layer = TRUE)
