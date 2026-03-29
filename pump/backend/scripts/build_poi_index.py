#!/usr/bin/env python3
"""
build_poi_index.py — Comprehensive POI index builder for Marg (Pune mobility planner).

Produces pump/data/processed/pune_poi.sqlite with 50,000+ entries by:
  1. Inserting hardcoded PUNE_MASTER_PLACES (250+ entries, importance=1.0)
  2. Running 12 Overpass API queries covering every POI category
  3. Expanding alternate names into separate rows
  4. Building FTS5 full-text search index

Usage:
    python scripts/build_poi_index.py
"""

import sqlite3
import requests
import time
import re
from pathlib import Path

# ── Paths ───────────────────────────────────────────────────────────────────────
BACKEND_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BACKEND_DIR.parent / "data" / "processed"
DB_PATH = DATA_DIR / "pune_poi.sqlite"

# ── Pune bounding box (covers Pune + PCMC + Hinjewadi + Kharadi + Wagholi) ────
BBOX = "18.20,73.60,18.80,74.30"

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
MAX_RETRIES = 3
RETRY_WAIT = 10
TIMEOUT = 120

# ── Importance scores by type ──────────────────────────────────────────────────
IMPORTANCE = {
    "metro_station": 1.0,
    "railway_station": 1.0,
    "airport": 1.0,
    "bus_station": 0.9,
    "college": 0.9,
    "university": 0.9,
    "hospital": 0.9,
    "landmark": 0.85,
    "locality": 0.8,
    "junction": 0.8,
    "government": 0.8,
    "it_park": 0.75,
    "road": 0.7,
    "market": 0.7,
    "mall": 0.7,
    "bus_stop": 0.6,
    "school": 0.5,
    "place_of_worship": 0.5,
    "shop": 0.4,
    "restaurant": 0.4,
}

# ══════════════════════════════════════════════════════════════════════════════════
# PUNE_MASTER_PLACES — Ground truth for commonly searched places
# ══════════════════════════════════════════════════════════════════════════════════
PUNE_MASTER_PLACES = {
    # ── METRO STATIONS (Purple Line / Line 1) ──────────────────────────────
    "PCMC": {"lat": 18.6298, "lon": 73.7997, "type": "metro_station", "alt": "Pimpri-Chinchwad Municipal Corporation"},
    "Sant Tukaram Nagar": {"lat": 18.6225, "lon": 73.8012, "type": "metro_station", "alt": "Tukaram Nagar metro"},
    "Bhosari": {"lat": 18.6134, "lon": 73.8025, "type": "metro_station", "alt": "Nashik Phata,Bhosari metro"},
    "Kasarwadi": {"lat": 18.6021, "lon": 73.8029, "type": "metro_station", "alt": "Kasarwadi metro"},
    "Phugewadi": {"lat": 18.5923, "lon": 73.8043, "type": "metro_station", "alt": "Fugewadi,Phugewadi metro"},
    "Dapodi": {"lat": 18.5828, "lon": 73.8063, "type": "metro_station", "alt": "Dapodi metro"},
    "Bopodi": {"lat": 18.5736, "lon": 73.8092, "type": "metro_station", "alt": "Bopodi metro"},
    "Khadki": {"lat": 18.5651, "lon": 73.8321, "type": "metro_station", "alt": "Kirkee,Khadki metro"},
    "Range Hill": {"lat": 18.5570, "lon": 73.8421, "type": "metro_station", "alt": "Range Hills metro"},
    "Shivajinagar Metro": {"lat": 18.5308, "lon": 73.8474, "type": "metro_station", "alt": "Shivaji Nagar metro station"},
    "Civil Court": {"lat": 18.5195, "lon": 73.8553, "type": "metro_station", "alt": "Civil Court metro,District Court interchange"},
    "Budhwar Peth": {"lat": 18.5142, "lon": 73.8567, "type": "metro_station", "alt": "Budhwar Peth metro"},
    "Mandai": {"lat": 18.5098, "lon": 73.8584, "type": "metro_station", "alt": "Mandai metro,Market Yard metro"},
    "Swargate": {"lat": 18.5021, "lon": 73.8612, "type": "metro_station", "alt": "Swargate metro,Swar Gate"},
    # ── METRO STATIONS (Aqua Line / Line 2) ────────────────────────────────
    "Vanaz": {"lat": 18.5089, "lon": 73.8012, "type": "metro_station", "alt": "Vanaz metro"},
    "Anand Nagar": {"lat": 18.5125, "lon": 73.8098, "type": "metro_station", "alt": "Anand Nagar metro"},
    "Ideal Colony": {"lat": 18.5142, "lon": 73.8178, "type": "metro_station", "alt": "Ideal Colony metro"},
    "Nal Stop": {"lat": 18.5163, "lon": 73.8254, "type": "metro_station", "alt": "Nal Stop metro,Nall Stop"},
    "Garware College": {"lat": 18.5189, "lon": 73.8334, "type": "metro_station", "alt": "Garware College metro"},
    "Deccan Gymkhana": {"lat": 18.5203, "lon": 73.8412, "type": "metro_station", "alt": "Deccan metro,Gymkhana metro"},
    "Chhatrapati Sambhaji Udyan": {"lat": 18.5198, "lon": 73.8489, "type": "metro_station", "alt": "Sambhaji Park metro,Sambhaji Garden"},
    "PMC": {"lat": 18.5196, "lon": 73.8553, "type": "metro_station", "alt": "PMC metro,Pune Municipal Corporation metro"},
    "Mangalwar Peth": {"lat": 18.5162, "lon": 73.8620, "type": "metro_station", "alt": "Mangalwar Peth metro"},
    "Pune Railway Station Metro": {"lat": 18.5281, "lon": 73.8742, "type": "metro_station", "alt": "Pune station metro,Pune Junction metro"},
    "Ruby Hall Clinic Metro": {"lat": 18.5354, "lon": 73.8812, "type": "metro_station", "alt": "Ruby Hall metro"},
    "Bund Garden": {"lat": 18.5421, "lon": 73.8887, "type": "metro_station", "alt": "Bund Garden metro"},
    "Yerawada": {"lat": 18.5498, "lon": 73.8952, "type": "metro_station", "alt": "Yerwada metro,Yerawada metro"},
    "Kalyani Nagar": {"lat": 18.5512, "lon": 73.9021, "type": "metro_station", "alt": "Kalyani Nagar metro"},
    "Ramwadi": {"lat": 18.5534, "lon": 73.9098, "type": "metro_station", "alt": "Ram Wadi metro"},
    # ── PUNE RAILWAY STATIONS ──────────────────────────────────────────────
    "Pune Junction": {"lat": 18.5283, "lon": 73.8742, "type": "railway_station", "alt": "Pune Station,Pune Railway Station,Pune Jn"},
    "Shivajinagar Station": {"lat": 18.5308, "lon": 73.8474, "type": "railway_station", "alt": "Shivaji Nagar Railway Station"},
    "Khadki Station": {"lat": 18.5651, "lon": 73.8321, "type": "railway_station", "alt": "Kirkee Station,Khadki Railway Station"},
    "Dapodi Station": {"lat": 18.5828, "lon": 73.8063, "type": "railway_station", "alt": "Dapodi Railway Station"},
    "Kasarwadi Station": {"lat": 18.6021, "lon": 73.8029, "type": "railway_station", "alt": "Kasarwadi Railway Station"},
    "Pimpri Station": {"lat": 18.6134, "lon": 73.8025, "type": "railway_station", "alt": "Pimpri Railway Station"},
    "Chinchwad Station": {"lat": 18.6285, "lon": 73.7998, "type": "railway_station", "alt": "Chinchwad Railway Station"},
    "Akurdi Station": {"lat": 18.6412, "lon": 73.7654, "type": "railway_station"},
    "Dehu Road Station": {"lat": 18.7012, "lon": 73.7542, "type": "railway_station", "alt": "Dehu Road Railway Station"},
    "Talegaon Station": {"lat": 18.7312, "lon": 73.6821, "type": "railway_station", "alt": "Talegaon Dabhade"},
    "Hadapsar Station": {"lat": 18.4985, "lon": 73.9212, "type": "railway_station"},
    "Manjari Station": {"lat": 18.5012, "lon": 73.9412, "type": "railway_station"},
    "Uruli Station": {"lat": 18.4512, "lon": 74.0012, "type": "railway_station"},
    # ── BUS DEPOTS AND MAJOR BUS STANDS ───────────────────────────────────
    "Swargate Bus Stand": {"lat": 18.5021, "lon": 73.8612, "type": "bus_station", "alt": "Swargate MSRTC,Swargate Bus Station"},
    "Shivajinagar Bus Depot": {"lat": 18.5342, "lon": 73.8512, "type": "bus_station", "alt": "Shivaji Nagar Bus Stand"},
    "Katraj Bus Stand": {"lat": 18.4521, "lon": 73.8612, "type": "bus_station"},
    "Hadapsar Bus Stand": {"lat": 18.4985, "lon": 73.9363, "type": "bus_station"},
    "Kothrud Bus Depot": {"lat": 18.5012, "lon": 73.8082, "type": "bus_station"},
    "Warje Bus Stand": {"lat": 18.4821, "lon": 73.8112, "type": "bus_station"},
    "Pimpri Bus Stand": {"lat": 18.6285, "lon": 73.7998, "type": "bus_station"},
    "Nigdi Bus Stand": {"lat": 18.6612, "lon": 73.7712, "type": "bus_station"},
    "Wakad Bus Stop": {"lat": 18.5912, "lon": 73.7632, "type": "bus_stop"},
    "Hinjewadi Bus Stop": {"lat": 18.5912, "lon": 73.7321, "type": "bus_stop", "alt": "Hinjawadi Bus Stop"},
    # ── PUNE AIRPORT ──────────────────────────────────────────────────────
    "Pune Airport": {"lat": 18.5822, "lon": 73.9197, "type": "airport", "alt": "Lohegaon Airport,Pune International Airport,Pune Domestic Airport"},
    "Lohegaon": {"lat": 18.5812, "lon": 73.9212, "type": "locality", "alt": "Lohegaon Airport area"},
    # ── MAJOR CHOWKS AND JUNCTIONS ─────────────────────────────────────────
    "Deccan Gymkhana Chowk": {"lat": 18.5203, "lon": 73.8401, "type": "junction", "alt": "Deccan Chowk"},
    "Shivajinagar": {"lat": 18.5308, "lon": 73.8474, "type": "locality", "alt": "Shivaji Nagar,Shivajinagar Pune"},
    "Kothrud": {"lat": 18.5012, "lon": 73.8082, "type": "locality"},
    "Warje": {"lat": 18.4821, "lon": 73.8112, "type": "locality", "alt": "Warje Malwadi"},
    "Hadapsar": {"lat": 18.4985, "lon": 73.9363, "type": "locality"},
    "Magarpatta": {"lat": 18.5102, "lon": 73.9289, "type": "locality", "alt": "Magarpatta City"},
    "Hinjewadi": {"lat": 18.5912, "lon": 73.7321, "type": "locality", "alt": "Hinjawadi,Hinjewadi IT Park,Rajiv Gandhi Infotech Park"},
    "Hinjewadi Phase 1": {"lat": 18.5912, "lon": 73.7321, "type": "locality"},
    "Hinjewadi Phase 2": {"lat": 18.5934, "lon": 73.7198, "type": "locality"},
    "Hinjewadi Phase 3": {"lat": 18.5956, "lon": 73.7054, "type": "locality"},
    "Wakad": {"lat": 18.5912, "lon": 73.7632, "type": "locality"},
    "Baner": {"lat": 18.5601, "lon": 73.7812, "type": "locality", "alt": "Baner Road"},
    "Aundh": {"lat": 18.5612, "lon": 73.8112, "type": "locality"},
    "Pimpri": {"lat": 18.6285, "lon": 73.7998, "type": "locality"},
    "Chinchwad": {"lat": 18.6412, "lon": 73.7812, "type": "locality"},
    "Nigdi": {"lat": 18.6612, "lon": 73.7712, "type": "locality"},
    "Akurdi": {"lat": 18.6412, "lon": 73.7654, "type": "locality"},
    "Bhosari": {"lat": 18.6312, "lon": 73.8421, "type": "locality"},
    "Khadki": {"lat": 18.5651, "lon": 73.8321, "type": "locality", "alt": "Kirkee"},
    "Yerawada": {"lat": 18.5498, "lon": 73.8952, "type": "locality", "alt": "Yerwada"},
    "Kalyani Nagar": {"lat": 18.5512, "lon": 73.9021, "type": "locality"},
    "Kharadi": {"lat": 18.5521, "lon": 73.9412, "type": "locality"},
    "Wagholi": {"lat": 18.5712, "lon": 73.9823, "type": "locality"},
    "Viman Nagar": {"lat": 18.5612, "lon": 73.9012, "type": "locality"},
    "Nagar Road": {"lat": 18.5512, "lon": 73.9312, "type": "road", "alt": "Pune Nagar Road,Pune-Ahmednagar Road"},
    "Kondhwa": {"lat": 18.4712, "lon": 73.8912, "type": "locality"},
    "Undri": {"lat": 18.4512, "lon": 73.9012, "type": "locality"},
    "Wanowrie": {"lat": 18.4902, "lon": 73.9023, "type": "locality", "alt": "Wanowri"},
    "Bibwewadi": {"lat": 18.4802, "lon": 73.8734, "type": "locality"},
    "Katraj": {"lat": 18.4521, "lon": 73.8612, "type": "locality"},
    "Narhe": {"lat": 18.4401, "lon": 73.8312, "type": "locality"},
    "Ambegaon": {"lat": 18.4301, "lon": 73.8012, "type": "locality"},
    "Dhayari": {"lat": 18.4512, "lon": 73.8012, "type": "locality"},
    "Sinhgad Road": {"lat": 18.4812, "lon": 73.8212, "type": "road", "alt": "Sinhgad Road area"},
    "Bavdhan": {"lat": 18.5212, "lon": 73.7712, "type": "locality"},
    "Pashan": {"lat": 18.5312, "lon": 73.8012, "type": "locality", "alt": "Pashan Road"},
    "Baner Road": {"lat": 18.5512, "lon": 73.7923, "type": "road"},
    "Sus": {"lat": 18.5512, "lon": 73.7521, "type": "locality"},
    "Mahalunge": {"lat": 18.5712, "lon": 73.7321, "type": "locality"},
    "Pimple Saudagar": {"lat": 18.5912, "lon": 73.8012, "type": "locality"},
    "Pimple Nilakh": {"lat": 18.6012, "lon": 73.7912, "type": "locality"},
    "Pimple Gurav": {"lat": 18.5812, "lon": 73.7912, "type": "locality"},
    "Sangvi": {"lat": 18.5712, "lon": 73.8212, "type": "locality"},
    "Vishrantwadi": {"lat": 18.5812, "lon": 73.8912, "type": "locality"},
    "Dhanori": {"lat": 18.5912, "lon": 73.8812, "type": "locality"},
    "Alandi Road": {"lat": 18.6012, "lon": 73.8812, "type": "road"},
    "Moshi": {"lat": 18.6612, "lon": 73.8512, "type": "locality"},
    "Chakan": {"lat": 18.7612, "lon": 73.8612, "type": "locality"},
    "Talegaon": {"lat": 18.7312, "lon": 73.6821, "type": "locality", "alt": "Talegaon Dabhade"},
    "Uruli Kanchan": {"lat": 18.4512, "lon": 74.1012, "type": "locality"},
    "Manjari": {"lat": 18.5012, "lon": 73.9412, "type": "locality"},
    "Kesnand": {"lat": 18.5012, "lon": 74.0012, "type": "locality"},
    "Markal": {"lat": 18.6512, "lon": 73.9512, "type": "locality"},
    "Lavale": {"lat": 18.5612, "lon": 73.7412, "type": "locality"},
    "Pirangut": {"lat": 18.5012, "lon": 73.7012, "type": "locality"},
    "Mulshi": {"lat": 18.5312, "lon": 73.5212, "type": "locality"},
    "Khed Shivapur": {"lat": 18.3512, "lon": 73.8512, "type": "locality"},
    # ── COLLEGES AND UNIVERSITIES ──────────────────────────────────────────
    "COEP": {"lat": 18.5304, "lon": 73.8577, "type": "college", "alt": "College of Engineering Pune,COEP Tech University"},
    "PICT": {"lat": 18.4578, "lon": 73.8501, "type": "college", "alt": "Pune Institute of Computer Technology"},
    "MIT Pune": {"lat": 18.5245, "lon": 73.8034, "type": "college", "alt": "MIT College of Engineering,Massachusetts Institute of Technology Pune"},
    "Symbiosis": {"lat": 18.5212, "lon": 73.8234, "type": "college", "alt": "Symbiosis International University,SIU Lavale"},
    "Fergusson College": {"lat": 18.5209, "lon": 73.8416, "type": "college", "alt": "FC Road college,Fergusson"},
    "SP College": {"lat": 18.5178, "lon": 73.8423, "type": "college", "alt": "Sir Parashurambhau College"},
    "Wadia College": {"lat": 18.5267, "lon": 73.8601, "type": "college"},
    "Sinhgad College of Engineering": {"lat": 18.4578, "lon": 73.8301, "type": "college", "alt": "SCOE"},
    "VIT Pune": {"lat": 18.5198, "lon": 73.8634, "type": "college", "alt": "Vishwakarma Institute of Technology"},
    "VIIT Pune": {"lat": 18.4898, "lon": 73.8212, "type": "college", "alt": "Vishwakarma Institute of Information Technology"},
    "DYPIET": {"lat": 18.4612, "lon": 73.8451, "type": "college", "alt": "DY Patil Institute of Engineering"},
    "Cummins College": {"lat": 18.4921, "lon": 73.8212, "type": "college", "alt": "Cummins College of Engineering for Women"},
    "Indira College": {"lat": 18.6012, "lon": 73.8012, "type": "college", "alt": "Indira College of Engineering"},
    "Bharati Vidyapeeth": {"lat": 18.4923, "lon": 73.8534, "type": "college", "alt": "Bharati Vidyapeeth University"},
    "BMCC": {"lat": 18.5245, "lon": 73.8401, "type": "college", "alt": "Brihan Maharashtra College of Commerce"},
    "Garware College": {"lat": 18.5189, "lon": 73.8334, "type": "college"},
    "Armed Forces Medical College": {"lat": 18.5612, "lon": 73.8712, "type": "college", "alt": "AFMC Pune"},
    "BJ Medical College": {"lat": 18.5178, "lon": 73.8534, "type": "college", "alt": "BJ Government Medical College,Sassoon Hospital area"},
    "KEM Hospital Medical College": {"lat": 18.5143, "lon": 73.8589, "type": "college"},
    "Pune University": {"lat": 18.5590, "lon": 73.8143, "type": "university", "alt": "SPPU,Savitribai Phule Pune University,University of Pune"},
    "SCTR": {"lat": 18.5201, "lon": 73.8234, "type": "college", "alt": "Sinhgad College of Technology and Research"},
    "RIMS": {"lat": 18.4901, "lon": 73.8012, "type": "college"},
    "College of Agriculture Pune": {"lat": 18.5501, "lon": 73.8501, "type": "college"},
    "DIC": {"lat": 18.5712, "lon": 73.8212, "type": "college", "alt": "Defence Institute of Advanced Technology"},
    "NCCS": {"lat": 18.5490, "lon": 73.8410, "type": "college", "alt": "National Chemical Laboratory,NCL"},
    "IISER Pune": {"lat": 18.5490, "lon": 73.8220, "type": "university", "alt": "Indian Institute of Science Education and Research"},
    "NDA": {"lat": 18.4312, "lon": 73.7723, "type": "university", "alt": "National Defence Academy,Khadakwasla"},
    "CME Pune": {"lat": 18.5701, "lon": 73.8701, "type": "college", "alt": "College of Military Engineering"},
    "AISSMS": {"lat": 18.5601, "lon": 73.8501, "type": "college", "alt": "AISSMS College of Engineering"},
    "MAEER MIT": {"lat": 18.5234, "lon": 73.8050, "type": "college"},
    # ── HOSPITALS ─────────────────────────────────────────────────────────
    "Ruby Hall Clinic": {"lat": 18.5354, "lon": 73.8812, "type": "hospital", "alt": "Ruby Hall Hospital"},
    "Sahyadri Hospital": {"lat": 18.5212, "lon": 73.8434, "type": "hospital", "alt": "Sahyadri Deccan"},
    "Jehangir Hospital": {"lat": 18.5312, "lon": 73.8712, "type": "hospital"},
    "Deenanath Mangeshkar Hospital": {"lat": 18.5101, "lon": 73.8234, "type": "hospital", "alt": "Deenanath Hospital"},
    "KEM Hospital": {"lat": 18.5143, "lon": 73.8589, "type": "hospital"},
    "Sassoon Hospital": {"lat": 18.5178, "lon": 73.8534, "type": "hospital", "alt": "B.J. Govt Medical College Hospital"},
    "Poona Hospital": {"lat": 18.5234, "lon": 73.8601, "type": "hospital"},
    "Columbia Asia": {"lat": 18.5601, "lon": 73.9012, "type": "hospital", "alt": "Columbia Asia Hospital Pune"},
    "Aditya Birla Memorial Hospital": {"lat": 18.6212, "lon": 73.7812, "type": "hospital"},
    "Lifepoint Hospital": {"lat": 18.5101, "lon": 73.9023, "type": "hospital"},
    "Noble Hospital": {"lat": 18.5012, "lon": 73.9123, "type": "hospital"},
    "Inamdar Hospital": {"lat": 18.5012, "lon": 73.9212, "type": "hospital"},
    "Hardikar Hospital": {"lat": 18.5201, "lon": 73.8712, "type": "hospital"},
    "Sanjeevan Hospital": {"lat": 18.5301, "lon": 73.8412, "type": "hospital"},
    "Medipoint Hospital": {"lat": 18.5512, "lon": 73.7823, "type": "hospital"},
    "Inlaks & Budhrani Hospital": {"lat": 18.5412, "lon": 73.8812, "type": "hospital"},
    # ── LANDMARKS ─────────────────────────────────────────────────────────
    "Shaniwar Wada": {"lat": 18.5195, "lon": 73.8553, "type": "landmark", "alt": "Shaniwarwada"},
    "Aga Khan Palace": {"lat": 18.5512, "lon": 73.9012, "type": "landmark"},
    "Rajiv Gandhi Zoological Park": {"lat": 18.4521, "lon": 73.8712, "type": "landmark", "alt": "Katraj Zoo,Pune Zoo"},
    "Osho Ashram": {"lat": 18.5356, "lon": 73.8923, "type": "landmark", "alt": "Osho International Meditation Resort"},
    "Empress Garden": {"lat": 18.5312, "lon": 73.8812, "type": "landmark", "alt": "Empress Botanical Gardens"},
    "Sinhagad Fort": {"lat": 18.3623, "lon": 73.7553, "type": "landmark", "alt": "Sinhgad Fort"},
    "Parvati Hill": {"lat": 18.4986, "lon": 73.8589, "type": "landmark", "alt": "Parvati Mandir,Parvati Temple"},
    "Chaturshringi Temple": {"lat": 18.5423, "lon": 73.8312, "type": "landmark", "alt": "Chatushrungi"},
    "Dagdusheth Halwai Temple": {"lat": 18.5156, "lon": 73.8559, "type": "landmark", "alt": "Dagdusheth Ganpati"},
    "Pataleshwar Cave Temple": {"lat": 18.5267, "lon": 73.8534, "type": "landmark"},
    "Kelkar Museum": {"lat": 18.5178, "lon": 73.8534, "type": "landmark", "alt": "Raja Kelkar Museum"},
    "National War Memorial": {"lat": 18.5312, "lon": 73.8701, "type": "landmark"},
    "Pune Cantonment": {"lat": 18.5312, "lon": 73.8812, "type": "landmark"},
    "Lal Mahal": {"lat": 18.5156, "lon": 73.8534, "type": "landmark"},
    # ── MARKETS AND COMMERCIAL ─────────────────────────────────────────────
    "FC Road": {"lat": 18.5209, "lon": 73.8416, "type": "road", "alt": "Fergusson College Road,FC Road Pune"},
    "JM Road": {"lat": 18.5245, "lon": 73.8401, "type": "road", "alt": "Jangli Maharaj Road"},
    "MG Road Pune": {"lat": 18.5312, "lon": 73.8701, "type": "road", "alt": "Mahatma Gandhi Road Pune"},
    "Laxmi Road": {"lat": 18.5112, "lon": 73.8534, "type": "road"},
    "Tilak Road": {"lat": 18.5012, "lon": 73.8634, "type": "road"},
    "Mandai": {"lat": 18.5098, "lon": 73.8584, "type": "market", "alt": "Mandai Market,Mahatma Phule Market"},
    "Market Yard": {"lat": 18.5012, "lon": 73.8734, "type": "market"},
    "Tulshi Baug": {"lat": 18.5112, "lon": 73.8589, "type": "market", "alt": "Tulsibaug"},
    "Phoenix Mall": {"lat": 18.5512, "lon": 73.9234, "type": "mall", "alt": "Phoenix Marketcity Pune"},
    "Amanora Mall": {"lat": 18.5102, "lon": 73.9389, "type": "mall"},
    "WestEnd Mall": {"lat": 18.5312, "lon": 73.8423, "type": "mall"},
    "Inorbit Mall": {"lat": 18.5612, "lon": 73.7923, "type": "mall"},
    "Pavilion Mall": {"lat": 18.5312, "lon": 73.8612, "type": "mall"},
    "Kumar Pacific Mall": {"lat": 18.4902, "lon": 73.8734, "type": "mall"},
    "SGS Mall": {"lat": 18.5245, "lon": 73.8412, "type": "mall"},
    "E-Square": {"lat": 18.5301, "lon": 73.8534, "type": "mall", "alt": "E Square Multiplex"},
    # ── IT PARKS AND TECH HUBS ─────────────────────────────────────────────
    "Rajiv Gandhi Infotech Park": {"lat": 18.5912, "lon": 73.7321, "type": "it_park", "alt": "Hinjewadi IT Park,Hinjawadi IT Park"},
    "Cybercity": {"lat": 18.5612, "lon": 73.9012, "type": "it_park", "alt": "Magarpatta Cybercity"},
    "SP Infocity": {"lat": 18.5512, "lon": 73.9412, "type": "it_park"},
    "Eon IT Park": {"lat": 18.5521, "lon": 73.9412, "type": "it_park"},
    "Software Technology Parks of India": {"lat": 18.5456, "lon": 73.8323, "type": "it_park", "alt": "STPI Pune"},
    "ICC Tech Park": {"lat": 18.5312, "lon": 73.8012, "type": "it_park"},
    # ── GOVERNMENT OFFICES ─────────────────────────────────────────────────
    "Pune Municipal Corporation": {"lat": 18.5196, "lon": 73.8553, "type": "government", "alt": "PMC Office"},
    "Collector Office Pune": {"lat": 18.5178, "lon": 73.8534, "type": "government"},
    "Pune Divisional Commissioner": {"lat": 18.5201, "lon": 73.8523, "type": "government"},
    "Mantralaya": {"lat": 18.9667, "lon": 72.8333, "type": "government", "alt": "Maharashtra Mantralaya Mumbai"},
    "Pimpri Chinchwad Municipal Corporation": {"lat": 18.6298, "lon": 73.7997, "type": "government", "alt": "PCMC Office"},
    "Pune Police Commissioner": {"lat": 18.5223, "lon": 73.8601, "type": "government"},
    # ── PUNE SPECIFIC AREAS ────────────────────────────────────────────────
    "Koregaon Park": {"lat": 18.5362, "lon": 73.8912, "type": "locality", "alt": "KP Pune"},
    "Camp": {"lat": 18.5178, "lon": 73.8801, "type": "locality", "alt": "Pune Camp,Cantonment"},
    "Sadashiv Peth": {"lat": 18.5134, "lon": 73.8523, "type": "locality"},
    "Narayan Peth": {"lat": 18.5123, "lon": 73.8512, "type": "locality"},
    "Kasba Peth": {"lat": 18.5156, "lon": 73.8567, "type": "locality"},
    "Shukrawar Peth": {"lat": 18.5145, "lon": 73.8556, "type": "locality"},
    "Nana Peth": {"lat": 18.5134, "lon": 73.8589, "type": "locality"},
    "Budhwar Peth": {"lat": 18.5142, "lon": 73.8567, "type": "locality"},
    "Ganesh Peth": {"lat": 18.5123, "lon": 73.8601, "type": "locality"},
    "Raviwar Peth": {"lat": 18.5145, "lon": 73.8612, "type": "locality"},
    "Somwar Peth": {"lat": 18.5156, "lon": 73.8623, "type": "locality"},
    "Mangalwar Peth": {"lat": 18.5162, "lon": 73.8620, "type": "locality"},
    "Guruwar Peth": {"lat": 18.5101, "lon": 73.8578, "type": "locality"},
    "Ganj Peth": {"lat": 18.5089, "lon": 73.8567, "type": "locality"},
    "Mahadwar Road": {"lat": 18.5101, "lon": 73.8556, "type": "road"},
    "Erandwane": {"lat": 18.5145, "lon": 73.8301, "type": "locality", "alt": "Erandwana"},
    "Model Colony": {"lat": 18.5289, "lon": 73.8345, "type": "locality"},
    "Karve Nagar": {"lat": 18.4934, "lon": 73.8223, "type": "locality"},
    "Karve Road": {"lat": 18.5012, "lon": 73.8234, "type": "road"},
    "Paud Road": {"lat": 18.5212, "lon": 73.7923, "type": "road", "alt": "Paud Phata"},
    "Senapati Bapat Road": {"lat": 18.5312, "lon": 73.8312, "type": "road", "alt": "SB Road"},
    "Nile Road": {"lat": 18.5489, "lon": 73.8456, "type": "road"},
    "Ganeshkhind Road": {"lat": 18.5412, "lon": 73.8234, "type": "road"},
    "University Road": {"lat": 18.5512, "lon": 73.8178, "type": "road"},
    "Law College Road": {"lat": 18.5245, "lon": 73.8345, "type": "road"},
    "Pulachi Wadi": {"lat": 18.5301, "lon": 73.8201, "type": "locality"},
    "Bavdhan Khurd": {"lat": 18.5112, "lon": 73.7701, "type": "locality"},
    "Nanded City": {"lat": 18.4623, "lon": 73.8201, "type": "locality"},
    "NIBM Road": {"lat": 18.4789, "lon": 73.9012, "type": "road"},
    "Fatimanagar": {"lat": 18.4912, "lon": 73.9101, "type": "locality"},
    "Salisbury Park": {"lat": 18.5012, "lon": 73.8912, "type": "locality"},
    "Gultekdi": {"lat": 18.4901, "lon": 73.8712, "type": "locality"},
    "Market Yard Gultekdi": {"lat": 18.4901, "lon": 73.8712, "type": "market"},
    "Pune Solapur Road": {"lat": 18.4712, "lon": 73.9212, "type": "road", "alt": "Solapur Road"},
    "Pune Satara Road": {"lat": 18.4512, "lon": 73.8612, "type": "road", "alt": "Satara Road"},
    "Pune Mumbai Highway": {"lat": 18.5801, "lon": 73.7401, "type": "road", "alt": "Mumbai Pune Expressway,Old Mumbai Highway"},
    "Pune Bangalore Highway": {"lat": 18.4201, "lon": 73.8201, "type": "road"},
}


# ── Overpass queries ────────────────────────────────────────────────────────────
OVERPASS_QUERIES = {
    "bus_stops": f"""[out:json][timeout:120];
(
  node["highway"="bus_stop"]({BBOX});
  node["public_transport"="stop_position"]({BBOX});
  node["public_transport"="platform"]({BBOX});
);
out body;""",

    "railway": f"""[out:json][timeout:120];
(
  node["railway"~"station|halt|tram_stop|subway_entrance"]({BBOX});
  way["railway"~"station|halt"]({BBOX});
);
out center body;""",

    "places": f"""[out:json][timeout:120];
(
  node["place"~"suburb|quarter|neighbourhood|village|town|city_block|locality"]({BBOX});
  relation["place"~"suburb|quarter|neighbourhood|village|town"]({BBOX});
);
out center body;""",

    "education": f"""[out:json][timeout:120];
(
  node["amenity"~"university|college|school|kindergarten"]({BBOX});
  way["amenity"~"university|college|school"]({BBOX});
  relation["amenity"~"university|college|school"]({BBOX});
);
out center body;""",

    "healthcare": f"""[out:json][timeout:120];
(
  node["amenity"~"hospital|clinic|pharmacy|dentist|doctors"]({BBOX});
  way["amenity"~"hospital|clinic"]({BBOX});
  relation["amenity"~"hospital|clinic"]({BBOX});
);
out center body;""",

    "transit": f"""[out:json][timeout:120];
(
  node["amenity"~"bus_station|ferry_terminal"]({BBOX});
  way["amenity"~"bus_station"]({BBOX});
  node["highway"="bus_stop"]["operator"~"PMPML|MSRTC|PMC"]({BBOX});
);
out center body;""",

    "landmarks": f"""[out:json][timeout:120];
(
  node["tourism"~"attraction|museum|viewpoint|hotel|guest_house|hostel"]({BBOX});
  node["historic"~"monument|memorial|fort|palace|ruins"]({BBOX});
  node["leisure"~"park|stadium|sports_centre|swimming_pool|garden"]({BBOX});
  way["tourism"~"attraction|museum"]({BBOX});
  way["historic"~"monument|memorial|fort"]({BBOX});
  way["leisure"~"park|stadium|sports_centre|garden"]({BBOX});
);
out center body;""",

    "government": f"""[out:json][timeout:120];
(
  node["amenity"~"townhall|courthouse|police|fire_station|post_office|bank"]({BBOX});
  way["amenity"~"townhall|courthouse|police|fire_station"]({BBOX});
  node["office"~"government|administrative"]({BBOX});
);
out center body;""",

    "roads": f"""[out:json][timeout:120];
nwr["highway"~"primary|secondary|tertiary|residential"]["name"]({BBOX});
out center body;""",

    "worship": f"""[out:json][timeout:120];
(
  node["amenity"="place_of_worship"]({BBOX});
  way["amenity"="place_of_worship"]({BBOX});
  relation["amenity"="place_of_worship"]({BBOX});
);
out center body;""",

    "shopping": f"""[out:json][timeout:120];
(
  node["shop"~"mall|supermarket|marketplace"]({BBOX});
  way["shop"~"mall|supermarket|marketplace"]({BBOX});
  way["landuse"="retail"]["name"]({BBOX});
);
out center body;""",

    "it_industrial": f"""[out:json][timeout:120];
(
  way["landuse"~"industrial|commercial"]["name"]({BBOX});
  node["office"="it"]({BBOX});
  way["building"~"office|industrial"]["name"]({BBOX});
);
out center body;""",
}


def fetch_overpass(query_name: str, query: str) -> dict | None:
    """Fetch Overpass data with retry logic."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            print(f"  [{attempt}/{MAX_RETRIES}] Fetching {query_name}...")
            resp = requests.post(
                OVERPASS_URL,
                data={"data": query},
                timeout=TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            n = len(data.get("elements", []))
            print(f"  ✓ {query_name}: {n} elements")
            return data
        except Exception as e:
            print(f"  ✗ {query_name} attempt {attempt} failed: {e}")
            if attempt < MAX_RETRIES:
                print(f"    Waiting {RETRY_WAIT}s before retry...")
                time.sleep(RETRY_WAIT)
    print(f"  ✗✗ {query_name}: all retries exhausted")
    return None


def determine_poi_type(tags: dict) -> str:
    """Determine POI type from OSM tags."""
    if tags.get("railway") in ("station", "halt"):
        return "railway_station"
    if tags.get("railway") in ("tram_stop", "subway_entrance"):
        return "metro_station"
    if tags.get("highway") == "bus_stop" or tags.get("public_transport") in ("stop_position", "platform"):
        return "bus_stop"
    if tags.get("amenity") == "bus_station":
        return "bus_station"
    if tags.get("amenity") == "university":
        return "university"
    if tags.get("amenity") == "college":
        return "college"
    if tags.get("amenity") == "school":
        return "school"
    if tags.get("amenity") == "hospital":
        return "hospital"
    if tags.get("amenity") == "clinic":
        return "clinic"
    if tags.get("amenity") == "place_of_worship":
        return "place_of_worship"
    if tags.get("amenity") in ("townhall", "courthouse", "police", "fire_station", "post_office"):
        return "government"
    if tags.get("office") in ("government", "administrative"):
        return "government"
    if tags.get("amenity") == "bank":
        return "bank"
    if tags.get("amenity") in ("pharmacy", "dentist", "doctors"):
        return "healthcare"
    if tags.get("tourism"):
        return "tourism"
    if tags.get("historic"):
        return "landmark"
    if tags.get("leisure"):
        return "leisure"
    if tags.get("place"):
        return "locality"
    if tags.get("shop"):
        return "shop"
    if tags.get("landuse") == "retail":
        return "market"
    if tags.get("landuse") in ("industrial", "commercial"):
        return "it_park"
    if tags.get("office") == "it":
        return "it_park"
    if tags.get("building") in ("office", "industrial"):
        return "it_park"
    if tags.get("highway"):
        return "road"
    return "other"


def get_importance(poi_type: str) -> float:
    """Get importance score for a POI type."""
    return IMPORTANCE.get(poi_type, 0.5)


def setup_db() -> sqlite3.Connection:
    """Create fresh SQLite database with proper schema."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    # Remove old DB
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(str(DB_PATH))
    cur = conn.cursor()

    cur.executescript("""
        CREATE TABLE pois (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            osm_id TEXT,
            osm_type TEXT,
            name TEXT NOT NULL,
            name_en TEXT,
            name_mr TEXT,
            alt_names TEXT,
            poi_type TEXT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            importance REAL DEFAULT 0.5
        );
        CREATE INDEX idx_poi_name ON pois(name COLLATE NOCASE);
        CREATE INDEX idx_poi_type ON pois(poi_type);
        CREATE INDEX idx_poi_coords ON pois(lat, lon);

        CREATE VIRTUAL TABLE pois_fts USING fts5(
            name, name_en, name_mr, alt_names, poi_type,
            content='pois', content_rowid='id',
            tokenize='unicode61 remove_diacritics 1'
        );

        CREATE TRIGGER pois_ai AFTER INSERT ON pois BEGIN
            INSERT INTO pois_fts(rowid, name, name_en, name_mr, alt_names, poi_type)
            VALUES (new.id, new.name, new.name_en, new.name_mr, new.alt_names, new.poi_type);
        END;
    """)
    conn.commit()
    return conn


def insert_master_places(conn: sqlite3.Connection) -> int:
    """Insert PUNE_MASTER_PLACES with importance=1.0. Returns count."""
    cur = conn.cursor()
    count = 0
    for name, data in PUNE_MASTER_PLACES.items():
        poi_type = data["type"]
        alt = data.get("alt", "")
        imp = max(get_importance(poi_type), 1.0)  # Master places always 1.0

        cur.execute(
            """INSERT INTO pois (osm_id, osm_type, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (f"master_{name.replace(' ', '_')}", "manual", name, name, "", alt, poi_type,
             data["lat"], data["lon"], imp),
        )
        count += 1
    conn.commit()
    return count


def insert_overpass_data(conn: sqlite3.Connection) -> int:
    """Run all Overpass queries and insert results. Returns count inserted."""
    cur = conn.cursor()

    # Collect existing master place keys to avoid duplicates
    master_keys = set()
    for name, data in PUNE_MASTER_PLACES.items():
        master_keys.add((name.lower(), round(data["lat"], 4), round(data["lon"], 4)))

    seen = set(master_keys)
    total_inserted = 0

    for query_name, query in OVERPASS_QUERIES.items():
        data = fetch_overpass(query_name, query)
        if not data or "elements" not in data:
            continue

        batch = []
        for el in data["elements"]:
            tags = el.get("tags", {})
            name = tags.get("name")
            if not name or not name.strip():
                continue
            # Skip purely numeric names
            if re.match(r"^\d+$", name.strip()):
                continue

            # Get coordinates
            if el["type"] == "node":
                lat = el.get("lat")
                lon = el.get("lon")
            elif "center" in el:
                lat = el["center"].get("lat")
                lon = el["center"].get("lon")
            else:
                continue

            if lat is None or lon is None:
                continue

            # Deduplicate
            dedup_key = (name.lower(), round(lat, 4), round(lon, 4))
            if dedup_key in seen:
                continue
            seen.add(dedup_key)

            osm_id = str(el.get("id", ""))
            osm_type = el.get("type", "node")
            poi_type = determine_poi_type(tags)
            name_en = tags.get("name:en", name)
            name_mr = tags.get("name:mr", "")

            # Build alt_names
            alt_parts = []
            for key in ("alt_name", "old_name", "name:mr", "name:en", "name:hi"):
                val = tags.get(key, "")
                if val and val != name:
                    alt_parts.append(val)
            alt_names = ",".join(alt_parts)

            importance = get_importance(poi_type)

            batch.append((
                osm_id, osm_type, name, name_en, name_mr, alt_names,
                poi_type, lat, lon, importance,
            ))

        if batch:
            cur.executemany(
                """INSERT INTO pois (osm_id, osm_type, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                batch,
            )
            conn.commit()
            total_inserted += len(batch)

        # Rate-limit between Overpass queries
        time.sleep(2)

    return total_inserted


def expand_alt_names(conn: sqlite3.Connection) -> int:
    """
    For each POI with alt_names, insert ADDITIONAL rows for each alternate name
    pointing to the same coordinates. Returns count of expanded rows.
    """
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance "
        "FROM pois WHERE alt_names IS NOT NULL AND alt_names != ''"
    )
    rows = cur.fetchall()

    seen_alts = set()
    batch = []
    for row in rows:
        _id, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance = row
        for alt in alt_names.split(","):
            alt = alt.strip()
            if not alt or alt.lower() == name.lower():
                continue
            dedup_key = (alt.lower(), round(lat, 4), round(lon, 4))
            if dedup_key in seen_alts:
                continue
            seen_alts.add(dedup_key)

            batch.append((
                f"alt_{_id}", "alt", alt, name_en, name_mr, name,
                poi_type, lat, lon, max(importance - 0.05, 0.3),
            ))

    if batch:
        cur.executemany(
            """INSERT INTO pois (osm_id, osm_type, name, name_en, name_mr, alt_names, poi_type, lat, lon, importance)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            batch,
        )
        conn.commit()

    return len(batch)


def print_summary(conn: sqlite3.Connection, master_count: int, overpass_count: int, alt_count: int):
    """Print final summary."""
    cur = conn.cursor()
    total = cur.execute("SELECT COUNT(*) FROM pois").fetchone()[0]

    cur.execute("SELECT poi_type, COUNT(*) FROM pois GROUP BY poi_type ORDER BY COUNT(*) DESC")
    type_counts = cur.fetchall()

    print("\n" + "=" * 60)
    print(f"✓ Inserted {master_count} records from PUNE_MASTER_PLACES")
    print(f"✓ Inserted {overpass_count} records from Overpass")
    print(f"✓ Expanded {alt_count} alternate name entries")
    print(f"✓ Total unique POIs: {total}")
    print(f"✓ By type:")
    for poi_type, count in type_counts:
        print(f"    {poi_type}={count}")
    print(f"✓ Saved to {DB_PATH}")
    print("=" * 60)


def main():
    print("=" * 60)
    print("Marg POI Index Builder — Comprehensive Pune coverage")
    print("=" * 60)

    print("\n[1/5] Setting up database...")
    conn = setup_db()

    print("\n[2/5] Inserting PUNE_MASTER_PLACES...")
    master_count = insert_master_places(conn)
    print(f"  ✓ {master_count} master places inserted")

    print("\n[3/5] Fetching from Overpass API (12 queries)...")
    overpass_count = insert_overpass_data(conn)

    print("\n[4/5] Expanding alternate names...")
    alt_count = expand_alt_names(conn)
    print(f"  ✓ {alt_count} alternate name rows added")

    print("\n[5/5] Summary")
    print_summary(conn, master_count, overpass_count, alt_count)

    conn.close()


if __name__ == "__main__":
    main()
