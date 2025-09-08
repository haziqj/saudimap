# Code to create maps of Saudi Arabia's regions and governorates. Retrieves data
# from OpenStreetMap using the osmdata package.
library(tidyverse)
library(sf)
library(osmdata)

# Bounding box for Saudi Arabia
bb <- getbb("Saudi Arabia")

# Fetch KSA boundary (Note: This is a rough outline, not admin regions)
ksa <- {
  q <- opq(bb) |>
    add_osm_feature("boundary", "administrative") |>
    add_osm_feature("admin_level", "2") |>
    add_osm_feature("name:en", "Saudi Arabia")
  y <- osmdata_sf(q)
  bind_rows(y$osm_multipolygons, y$osm_polygons) |>
    st_make_valid() |>
    summarise(geometry = st_union(geometry))  # dissolve
}

# Pull all admin boundaries for levels 4 (regions) and 5/6 (governorates)
x <-
  opq(bb) |>
  add_osm_feature("boundary", "administrative") |>
  add_osm_feature("admin_level", c("4", "5", "6")) |>
  osmdata_sf()

polys <-
  bind_rows(x$osm_multipolygons, x$osm_polygons) |>
  st_make_valid() |>
  mutate(name = coalesce(`name:en`, name, `name:ar`))

# Remove non-Saudi Arabia polygons (some spillover from neighboring countries)
# Classic s2 edge crossing problem: the Saudi Arabia boundary relation and the
# governorate/region polygons from OSM aren’t perfectly clean, so when s2 tries
# to do a geodesic intersection it trips over invalid edges. Workaround is to
# switch to planar (GEOS) for the intersection step.
old <- sf_use_s2()
sf_use_s2(FALSE)
polys <- suppressWarnings(
  st_intersection(st_make_valid(polys), st_make_valid(ksa))
)
sf_use_s2(old)

# Remove non polygons (lines, points, etc)
polys <-
  polys |>
  st_make_valid() |>
  st_collection_extract("POLYGON") |>
  st_cast("MULTIPOLYGON", warn = FALSE)

# Create regions and governorates datasets
reg_sf <-
  polys |>
  filter(admin_level == "4") |>
  select(region = name, geometry, population, population.date, source,
         source.population) |>
  mutate(
    region = gsub(" Province", "", region),
    region = gsub(" Region", "", region),
  ) |>
  st_make_valid()

gov_sf <-
  polys |>
  filter(admin_level %in% c("5", "6")) |>
  select(governorate = name, geometry, population, population.date, source,
         source.population) |>
  mutate(
    governorate = gsub(" Governorate", "", governorate),
    governorate = gsub("Governorate of ", "", governorate),
    governorate = case_when(
      governorate == "Riyadh governorate" ~ "Riyadh Governorate",
      governorate == "Jidda" ~ "Jeddah",
      governorate == "Missan" ~ "Maysan",
      governorate == "Faifa" ~ "Fayfa",
      governorate == "Abu `Arish" ~ "Abu Arish",
      governorate == "Dhahran Al Janub" ~ "Zahran Al Janub",
      governorate == "Alddayer" ~ "Ad Dair",
      TRUE ~ governorate
    )
  ) |>
  st_make_valid()

# Now need to assign region names to governorates using list obtained from OSM
# https://wiki.openstreetmap.org/wiki/Saudi_Arabia/Admin_Boundaries_of_Regions_and_Governorates_Import
gov_df <- read_csv("R/governorates.csv")
gov_sf <- left_join(gov_sf, gov_df)

# Test plot
ggplot() +
  geom_sf(data = gov_sf, aes(fill = region), alpha = 0.65) +
  geom_sf(data = reg_sf, fill = NA, linewidth = 0.5, col = "black") +
  ggrepel::geom_label_repel(
    data = reg_sf,
    aes(label = region, geometry = geometry),
    size = 2.7,
    stat = "sf_coordinates",
    max.overlaps = Inf,
    min.segment.length = 0,
    segment.size = 0.3,
    segment.curvature = 0.1,
    force = 5
  ) +
  scale_fill_viridis_d(option = "mako", guide = "none") +
  theme_void()

# Save datasets
save(reg_sf, gov_sf, gov_df, file = "data/ksamaps.Rdata", compress = "xz")
