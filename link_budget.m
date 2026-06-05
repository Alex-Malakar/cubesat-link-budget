% OKSat Link Budget Analysis — UHF Downlink & Uplink
% Hardware: GomSpace AX100U transceiver + ANT430 antenna

clear; clc; close all;

%% 1. Constants
c   = 299792458;
k_B = 1.380649e-23;
R_E = 6371.0;           % km

%% 2. Parameters

% Frequency
f_Hz   = 438e6;         % AX100 DS p.18
lambda = c / f_Hz;

% Downlink (satellite → ground)
P_tx_dBW    = 10*log10(1.0);   
G_tx_dBi    = 0.65;            
G_rx_dBi    = 17.7;            
L_tx_line   = 0.5;             
L_rx_line   = 0.15;            
T_sys_DL    = 900;             
R_dBHz      = 10*log10(19200); 

% Uplink (ground → satellite)
P_tx_GS_dBW = 14.0;            
G_tx_GS_dBi = 17.7;            
L_tx_GS     = 1.6;             
G_rx_sat    = 0.65;            
L_rx_sat    = 0.2;            
T_sys_UL    = 234;             
R_UL_dBHz   = 10*log10(9600);  

% Shared losses
L_pol  = 3.0;   % AX100 DS p.18-19
L_misc = 3.0;   % wire_comm.pdf Table 18
L_ion  = 1.0;   % wire_comm.pdf Table 19

% Threshold & mask
EbNo_threshold = 7.8;   % AX100 DS p.18
e_min_deg      = 10;    % wire_comm.pdf §8.6.1

%% 3. Load GMAT Ephemeris
data  = readmatrix('GMAT_output.txt', 'NumHeaderLines', 1, 'Delimiter', ',');
t_s   = data(:,1);
gs_x  = data(:,2);  gs_y = data(:,3);  gs_z = data(:,4);
sat_x = data(:,8);  sat_y = data(:,9); sat_z = data(:,10);
gs_pos = [gs_x(1), gs_y(1), gs_z(1)];

%% 4. Contact Windows
contact_start_utc = [
    11*3600 + 37*60 + 0.381;
    13*3600 + 16*60 + 41.589;
    14*3600 + 59*60 + 46.443;
    16*3600 + 43*60 + 19.557;
    18*3600 + 25*60 + 53.628;
    20*3600 +  8*60 + 33.472;
];
contact_stop_utc = [
    11*3600 + 42*60 +  1.988;
    13*3600 + 26*60 +  5.927;
    15*3600 +  8*60 + 27.614;
    16*3600 + 51*60 + 28.220;
    18*3600 + 35*60 +  4.810;
    20*3600 + 17*60 +  3.328;
];
contact_duration = contact_stop_utc - contact_start_utc;
n_passes = length(contact_start_utc);

fprintf('Loaded %d passes | Total contact: %.1f s (%.1f min)\n', ...
    n_passes, sum(contact_duration), sum(contact_duration)/60);

%% 5. Geometry & Downlink Budget
n_steps    = length(t_s);
elev_deg   = nan(n_steps, 1);
slant_km   = nan(n_steps, 1);
EbNo_dB    = nan(n_steps, 1);
in_contact = false(n_steps, 1);

for i = 1:n_steps
    r_vec  = [sat_x(i), sat_y(i), sat_z(i)] - gs_pos;
    r_km   = norm(r_vec);
    gs_hat = gs_pos / norm(gs_pos);
    el_rad = asin(max(-1, min(1, dot(r_vec, gs_hat) / r_km)));
    el_deg = rad2deg(el_rad);

    elev_deg(i) = el_deg;
    slant_km(i) = r_km;

    if el_deg < e_min_deg; continue; end

    for p = 1:n_passes
        if t_s(i) >= contact_start_utc(p) && t_s(i) <= contact_stop_utc(p)
            in_contact(i) = true; break;
        end
    end

    FSPL_dB = 20*log10(4*pi*r_km*1e3/lambda);
    L_atm   = max(0.04, min(0.23, 0.04/sin(el_rad)));  % wire_comm.pdf eq.22

    P_rx_dBW  = P_tx_dBW + G_tx_dBi - L_tx_line ...
              - FSPL_dB - L_atm - L_ion - L_pol - L_misc ...
              + G_rx_dBi - L_rx_line;
    N0_dBW_Hz = 10*log10(k_B * T_sys_DL);
    EbNo_dB(i) = P_rx_dBW - R_dBHz - N0_dBW_Hz;
end

link_margin   = EbNo_dB - EbNo_threshold;
valid         = ~isnan(EbNo_dB);
contact_valid = valid & in_contact;

%% 6. Summary
fprintf('\n=== UHF Downlink Summary ===\n');
if any(contact_valid)
    fprintf('Min Eb/No:  %.1f dB\n', min(EbNo_dB(contact_valid)));
    fprintf('Max Eb/No:  %.1f dB\n', max(EbNo_dB(contact_valid)));
    fprintf('Min margin: %.1f dB\n', min(link_margin(contact_valid)));
    fprintf('Link closed all passes: %s\n', string(all(link_margin(contact_valid) > 0)));
end

%% 7. Analytic Sweep (DL + UL)
el_sweep      = linspace(e_min_deg, 90, 500);
H_km          = 650;
EbNo_DL_sweep = zeros(size(el_sweep));
EbNo_UL_sweep = zeros(size(el_sweep));

for j = 1:length(el_sweep)
    el_r    = deg2rad(el_sweep(j));
    r_m_j   = (sqrt((R_E+H_km)^2 - R_E^2*cos(el_r)^2) - R_E*sin(el_r)) * 1e3;
    FSPL_j  = 20*log10(4*pi*r_m_j/lambda);
    L_atm_j = max(0.04, min(0.23, 0.04/sin(el_r)));

    P_rx_DL = P_tx_dBW + G_tx_dBi - L_tx_line ...
            - FSPL_j - L_atm_j - L_ion - L_pol - L_misc ...
            + G_rx_dBi - L_rx_line;
    EbNo_DL_sweep(j) = P_rx_DL - R_dBHz - 10*log10(k_B*T_sys_DL);

    P_rx_UL = P_tx_GS_dBW + G_tx_GS_dBi - L_tx_GS ...
            - FSPL_j - L_atm_j - L_ion - L_pol - L_misc ...
            + G_rx_sat - L_rx_sat;
    EbNo_UL_sweep(j) = P_rx_UL - R_UL_dBHz - 10*log10(k_B*T_sys_UL);
end

%% 8. Plots

% Figure 1: Eb/No vs Elevation
figure('Name','Eb/No vs Elevation','Position',[100 100 780 520]);
hold on; grid on; box on;

fill([el_sweep, fliplr(el_sweep)], ...
     [EbNo_DL_sweep, fliplr(repmat(EbNo_threshold, size(el_sweep)))], ...
     [0.8 1 0.8], 'EdgeColor','none', 'FaceAlpha', 0.4);
fill([el_sweep, fliplr(el_sweep)], ...
     [EbNo_UL_sweep, fliplr(repmat(EbNo_threshold, size(el_sweep)))], ...
     [0.8 0.88 1], 'EdgeColor','none', 'FaceAlpha', 0.3);

yline(EbNo_threshold, 'k--', 'LineWidth', 1.5, ...
    'Label', sprintf('%.1f dB threshold', EbNo_threshold), ...
    'LabelHorizontalAlignment','left', 'LabelVerticalAlignment','bottom');
xline(e_min_deg, 'k:', 'LineWidth', 1.2, ...
    'Label', sprintf('%d° mask', e_min_deg), 'LabelHorizontalAlignment','right');

plot(el_sweep, EbNo_DL_sweep, 'r-',  'LineWidth', 2, 'DisplayName', 'UHF DL (19.2 kbps, sat→GS)');
plot(el_sweep, EbNo_UL_sweep, 'b--', 'LineWidth', 2, 'DisplayName', 'UHF UL (9.6 kbps,  GS→sat)');

DL_margin = EbNo_DL_sweep(1) - EbNo_threshold;
UL_margin = EbNo_UL_sweep(1) - EbNo_threshold;
text(e_min_deg+1, EbNo_threshold + DL_margin*0.5, sprintf('DL %.1f dB', DL_margin), ...
    'FontSize', 9, 'Color', [0.7 0 0]);
text(e_min_deg+1, EbNo_threshold + UL_margin*0.5, sprintf('UL %.1f dB', UL_margin), ...
    'FontSize', 9, 'Color', [0 0 0.8]);

xlabel('Ground Station Elevation Angle (deg)', 'FontSize', 12);
ylabel('Eb/No (dB)', 'FontSize', 12);
title('OKSat UHF Link Budget — Eb/No vs Elevation', 'FontSize', 13);
legend('Location','southeast', 'FontSize', 10);
ylim([0, ceil(max(EbNo_UL_sweep)/10)*10 + 5]);
xlim([0 90]);

% Figure 2: Eb/No over contact passes
figure('Name','Eb/No Over Contact Passes','Position',[100 660 900 420]);
hold on; grid on; box on;

t_hr = t_s / 3600;
for p = 1:n_passes
    fill([contact_start_utc(p), contact_stop_utc(p), ...
          contact_stop_utc(p), contact_start_utc(p)] / 3600, ...
         [-10 -10 80 80], [0.9 0.95 1], 'EdgeColor','none', 'FaceAlpha', 0.6);
end
plot(t_hr(valid), EbNo_dB(valid), 'r.', 'MarkerSize', 4, 'DisplayName', 'DL Eb/No');
yline(EbNo_threshold, 'k--', 'LineWidth', 1.5, ...
    'Label', sprintf('%.1f dB threshold', EbNo_threshold), ...
    'LabelHorizontalAlignment','left');

xlabel('Elapsed Time (hours)', 'FontSize', 12);
ylabel('Eb/No (dB)', 'FontSize', 12);
title('UHF Downlink Eb/No — GMAT Contact Windows (22 Jul 2014)', 'FontSize', 13);
legend({'Contact window','DL Eb/No','Threshold'}, 'Location','northeast', 'FontSize', 10);
ylim([-5 45]); xlim([0 max(t_hr)]);

% Figure 3: Geometry
figure('Name','Geometry','Position',[900 100 750 480]);
tiledlayout(2,1,'TileSpacing','compact');

nexttile; hold on; grid on; box on;
for p = 1:n_passes
    fill([contact_start_utc(p), contact_stop_utc(p), ...
          contact_stop_utc(p), contact_start_utc(p)] / 3600, ...
         [-90 -90 90 90], [0.9 0.95 1], 'EdgeColor','none', 'FaceAlpha', 0.6);
end
plot(t_hr, elev_deg, 'b-', 'LineWidth', 1);
yline(e_min_deg, 'r--', 'LineWidth', 1, 'Label', sprintf('%d° mask', e_min_deg));
xlabel('Elapsed Time (hours)'); ylabel('Elevation (deg)');
title('Ground Station Elevation Angle'); ylim([-90 90]);

nexttile; hold on; grid on; box on;
for p = 1:n_passes
    fill([contact_start_utc(p), contact_stop_utc(p), ...
          contact_stop_utc(p), contact_start_utc(p)] / 3600, ...
         [0 0 16000 16000], [0.9 0.95 1], 'EdgeColor','none', 'FaceAlpha', 0.6);
end
plot(t_hr, slant_km, 'k-', 'LineWidth', 1);
xlabel('Elapsed Time (hours)'); ylabel('Slant Range (km)');
title('Slant Range to Ground Station');

%% 9. Per-Pass Summary Table
fprintf('\n=== Per-Pass Link Summary ===\n');
fprintf('%-6s %-10s %-10s %-12s %-12s %-10s %-10s\n', ...
    'Pass','Start(hr)','Stop(hr)','Dur(s)','MinEbNo(dB)','MaxEl(deg)','Margin(dB)');
fprintf('%s\n', repmat('-',1,72));

for p = 1:n_passes
    mask = t_s >= contact_start_utc(p) & t_s <= contact_stop_utc(p) & ~isnan(EbNo_dB);
    if ~any(mask)
        fprintf('%-6d  (no ephemeris points in window)\n', p); continue;
    end
    fprintf('%-6d %-10.3f %-10.3f %-12.1f %-12.1f %-10.1f %-10.1f\n', p, ...
        contact_start_utc(p)/3600, contact_stop_utc(p)/3600, contact_duration(p), ...
        min(EbNo_dB(mask)), max(elev_deg(mask)), min(EbNo_dB(mask)) - EbNo_threshold);
end
