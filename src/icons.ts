import { Icon } from "@raycast/api";
import type { Place } from "./places";

/**
 * Maps OpenStreetMap's key/value taxonomy onto Raycast's icon set, so a cafe
 * looks like a cafe in the results list. Matched most-specific first: the
 * `osm_value` ("cafe") wins over the `osm_key` ("amenity").
 */

const BY_VALUE: Record<string, Icon> = {
  cafe: Icon.MugSteam,
  coffee_shop: Icon.MugSteam,
  restaurant: Icon.Mug,
  fast_food: Icon.Mug,
  bar: Icon.Mug,
  pub: Icon.Mug,
  biergarten: Icon.Mug,
  bakery: Icon.Mug,

  hotel: Icon.House,
  hostel: Icon.House,
  guest_house: Icon.House,
  house: Icon.House,
  residential: Icon.House,
  apartments: Icon.Building,

  museum: Icon.Star,
  attraction: Icon.Star,
  artwork: Icon.Star,
  viewpoint: Icon.Binoculars,
  place_of_worship: Icon.Heart,

  park: Icon.Tree,
  garden: Icon.Tree,
  forest: Icon.Tree,
  beach: Icon.Umbrella,
  peak: Icon.Mountain,

  hospital: Icon.MedicalSupport,
  clinic: Icon.MedicalSupport,
  pharmacy: Icon.MedicalSupport,
  doctors: Icon.MedicalSupport,
  dentist: Icon.MedicalSupport,

  school: Icon.Book,
  university: Icon.Book,
  college: Icon.Book,
  library: Icon.Book,

  bank: Icon.BankNote,
  atm: Icon.BankNote,
  bureau_de_change: Icon.Coins,

  cinema: Icon.FilmStrip,
  theatre: Icon.FilmStrip,
  nightclub: Icon.Music,
  stadium: Icon.SoccerBall,
  pitch: Icon.SoccerBall,
  gym: Icon.Weights,
  fitness_centre: Icon.Weights,

  parking: Icon.Car,
  fuel: Icon.Car,
  car_rental: Icon.Car,
  charging_station: Icon.Plug,
  station: Icon.Train,
  halt: Icon.Train,
  tram_stop: Icon.Train,
  subway_entrance: Icon.Train,
  bus_stop: Icon.Lorry,
  bus_station: Icon.Lorry,
  aerodrome: Icon.Airplane,
  terminal: Icon.Airplane,
  ferry_terminal: Icon.Boat,

  office: Icon.Building,
  commercial: Icon.Building,
  coworking_space: Icon.Building,
  post_office: Icon.Envelope,
  police: Icon.Shield,
  fire_station: Icon.Torch,

  city: Icon.Building,
  town: Icon.Building,
  suburb: Icon.Building,
  neighbourhood: Icon.Building,
  village: Icon.House,
  hamlet: Icon.House,
  country: Icon.Globe,
  state: Icon.Globe,
  region: Icon.Globe,
};

const BY_KEY: Record<string, Icon> = {
  shop: Icon.Cart,
  amenity: Icon.Pin,
  tourism: Icon.Star,
  leisure: Icon.Tree,
  natural: Icon.Tree,
  highway: Icon.Map,
  railway: Icon.Train,
  aeroway: Icon.Airplane,
  waterway: Icon.Boat,
  building: Icon.Building,
  office: Icon.Building,
  healthcare: Icon.MedicalSupport,
  place: Icon.Geopin,
  boundary: Icon.Globe,
};

export function iconFor(place: Place): Icon {
  if (place.osmValue && BY_VALUE[place.osmValue]) return BY_VALUE[place.osmValue];
  if (place.osmKey && BY_KEY[place.osmKey]) return BY_KEY[place.osmKey];
  return Icon.Pin;
}
