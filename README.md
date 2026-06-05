# cubesat-link-budget
# CubeSat Link Budget Analysis
> **Note:** This project was built for personal learning after completing the OKSat 3U CubeSat
> senior design project at Oklahoma State University (Spring 2026). The hardware parameters
> reflect the OKSat mission but the methodology applies to any UHF LEO CubeSat link budget.
> Not actively maintained — use freely.

MATLAB script for UHF downlink and uplink link budget analysis of a 3U CubeSat in LEO. Computes Eb/No vs elevation angle and evaluates link closure across all GMAT contact windows.

---

## Hardware

| Component | Part | Key Specs |
|---|---|---|
| Transceiver | GomSpace NanoCom AX100U | 1 W Tx, 19.2 kbps max, GMSK, UHF 430–440 MHz |
| Satellite Antenna | GomSpace NanoCom ANT430 | −0.3 to 1.6 dBi, omnidirectional, circularly polarized |
| Ground Station Antenna | 450CP42 Yagi | ~17.7 dBi, circularly polarized |

---

## Antenna Radiation Patterns

### GomSpace NanoCom ANT430 — Satellite
Canted turnstile antenna mounted on the −Z face. Nearly omnidirectional with no blind spots.
Peak gain 1.4 dBi along Z-axis, minimum −1.0 dBi. | ANT430 DS §2.2.3

<img width="573" height="466" alt="Image" src="https://github.com/user-attachments/assets/9219e688-947b-45cd-8c0b-8bec2a0c08cd" />

### M2 450CP42 Yagi — Ground Station
21-element Yagi at 435–455 MHz. Highly directional at ~17.7 dBi — tracks the satellite across the pass.

<img width="794" height="607" alt="Image" src="https://github.com/user-attachments/assets/c3d16342-a212-40a8-9355-3bd777b926fa" />
---

## Link Budget Results

Both UHF downlink and uplink close comfortably above the 7.8 dB Eb/No threshold at all elevations above the 10° mask. Downlink is the constraining direction at ~7 dB margin; uplink has ~29 dB margin due to the higher ground station transmit power and lower satellite receiver noise temperature.

<img width="1024" height="756" alt="Image" src="https://github.com/user-attachments/assets/1ed178cd-283c-4d86-a847-263260a3f629" />

---

## Input Files

| File | Description |
|---|---|
| `GMAT_output.txt` | GMAT ephemeris — satellite and ground station ECEF positions at each timestep |
| `Contact.txt` | Contact window report — pass start/stop times and durations |

Both files are exported directly from GMAT. The ephemeris epoch is **22 Jul 2014 00:00:00 UTC** (t = 0 s). Contact window times in `Contact.txt` are in UTC and are converted to elapsed seconds internally.

---

## Quick Start

1. Place `GMAT_output.txt` and `Contact.txt` in the same directory as `link_budget.m`.
2. Run `link_budget.m` in MATLAB.
3. Three figures and a console summary will be produced.

---

## Link Budget Model

### Downlink (satellite → ground)

$$E_b/N_0 = P_{tx} + G_{tx} - L_{tx} - \text{FSPL} - L_{atm} - L_{ion} - L_{pol} - L_{misc} + G_{rx} - L_{rx} - 10\log_{10}(R) - 10\log_{10}(k_B T_{sys})$$

### Uplink (ground → satellite)

Same equation with ground station and satellite roles swapped.

### Parameter Summary

| Parameter | Downlink | Uplink | Source |
|---|---|---|---|
| Tx power | 0 dBW (1 W) | 14.0 dBW (25 W) | AX100 DS p.18–19 |
| Tx antenna gain | 0.65 dBi (ANT430) | 17.7 dBi (Yagi) | ANT430 DS §2.2.3 |
| Tx line loss | 0.5 dB | 1.6 dB | AX100 DS p.18–19 |
| Rx antenna gain | 17.7 dBi (Yagi) | 0.65 dBi (ANT430) | ANT430 DS §2.2.3 |
| Rx line loss | 0.15 dB | 0.2 dB | AX100 DS p.18–19 |
| System noise temp | 900 K | 234 K | AX100 DS p.19 |
| Data rate | 19,200 bps | 9,600 bps | AX100 DS p.1, p.19 |
| Polarization loss | 3.0 dB | 3.0 dB | AX100 DS p.18–19 |
| Ionospheric loss | 1.0 dB | 1.0 dB | AX100 DS p.18–19 |
| Misc system margin | 3.0 dB | 3.0 dB | AX100 DS p.18–19 |
| Eb/No threshold | 7.8 dB | 7.8 dB | AX100 DS p.18 (GMSK, Conv R=1/2 K=7, BER 1×10⁻⁵) |
| Elevation mask | 10° | 10° | Assumed |

### Atmospheric Loss

$$L_{atm} = \frac{0.04}{\sin(e)}, \quad \text{clamped to } [0.04,\ 0.23] \text{ dB}$$

Where 0.04 dB is the zenith water vapor absorption at 435 MHz (SMAD Fig. 13-10). The `1/sin(e)` factor accounts for the longer atmospheric path length at low elevation angles.

### Free-Space Path Loss

$$\text{FSPL} = 20\log_{10}\!\left(\frac{4\pi r}{\lambda}\right)$$

Slant range $r$ is computed from ECEF positions in the GMAT ephemeris. For the analytic elevation sweep, slant range is derived from spherical Earth geometry at 650 km altitude.

---

## Outputs

**Console**
- Total contact time across all passes
- Min/max/mean Eb/No and minimum link margin during contact windows
- Per-pass table: start time, stop time, duration, min Eb/No, max elevation, link margin

**Figure 1 — Eb/No vs Elevation**
Analytic sweep from 10° to 90° for both UHF downlink (red) and uplink (blue dashed). Shows shaded margin bands and annotates margin at the 10° elevation mask.

**Figure 2 — Eb/No over GMAT Passes**
Downlink Eb/No at each GMAT timestep, with contact windows shaded. Confirms link closure across all 6 passes on 22 Jul 2014.

**Figure 3 — Geometry**
Ground station elevation angle and slant range vs elapsed time, with contact windows shaded.

---

## Key Results

The downlink is the constraining direction. At 10° minimum elevation:

- **UHF Downlink margin: ~7 dB** above the 7.8 dB threshold
- **UHF Uplink margin: ~29 dB** above threshold — not the limiting link

The large uplink margin is expected: the ground station transmits 25× more power than the satellite, uses a high-gain directional antenna, and the AX100 satellite receiver has a low noise temperature (234 K) because it looks toward cold space.

---

## Assumptions & Limitations

- Polarization loss is fixed at 3 dB. The ANT430 is mounted in the −Z direction, meaning the minimum boresight error to the ground station is always 90°. Actual Faraday rotation and elevation-dependent polarization are not modeled.
- Ground station noise temperature (900 K) is an assumed value for a rural environment. The AX100 datasheet reference budget uses 10,035 K for a noisy city.
- Satellite Tx line loss (0.5 dB) is adopted from the GomSpace AX100 reference budget and has not been measured on physical hardware.
- Ionospheric loss (1.0 dB) is a fixed conservative estimate. Actual loss varies with TEC, time of day, and solar activity.
- Free-space path loss uses the Friis transmission equation with no multipath, scattering, or atmospheric refraction.
- GMAT ephemeris covers only ~1 day (22 Jul 2014). Results are representative of a single day and do not account for beta angle variation over a multi-year mission.

---

## References

| # | Document |
|---|---|
| [1] | GomSpace NanoCom AX100 Datasheet, DS1013823 v3.7, 29 Nov 2019 |
| [2] | GomSpace NanoCom ANT430 Datasheet, DS1010590 v3.5, 02 Aug 2018 |
| [3] | Wertz & Larson, *Space Mission Analysis and Design* (SMAD), 3rd ed. — Fig. 13-10 |
