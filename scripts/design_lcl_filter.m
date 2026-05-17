%DESIGN_LCL_FILTER First-pass LCL filter design for the switching VSI.

if ~exist('p', 'var') || ~isfield(p, 'spec')
    run(fullfile(fileparts(mfilename('fullpath')), 'inv_params_init.m'));
end

omega = p.grid.omega;
Vdc = p.dc.Vdc;
fsw = p.switch.fsw;
Ipk = p.spec.IAC_ref_high;

% Converter-side inductor from the common two-level VSI ripple estimate.
L1_min = Vdc / (8 * fsw * p.spec.delta_i_max);
L1 = 2.0e-3;
R1 = 50e-3;

% Limit capacitor current to roughly 5% of rated phase current at 50 Hz.
Ic_cap_limit = 0.05 * Ipk;
Cf_max = Ic_cap_limit / (omega * p.grid.Vphase_peak);
Cf = 10e-6;

% Grid-side inductor selected to place resonance below fsw/10 and well
% above the 50 Hz fundamental.
L2 = 1.0e-3;
R2 = 50e-3;

f_res = (1 / (2 * pi)) * sqrt((L1 + L2) / (L1 * L2 * Cf));
omega_res = 2 * pi * f_res;
Rd = 1 / (3 * omega_res * Cf);

delta_i_est = Vdc / (8 * fsw * L1);

% High-frequency current divider estimate at the switching frequency.
Zc_fsw = 1 / (1j * 2 * pi * fsw * Cf) + Rd;
Zl2_fsw = R2 + 1j * 2 * pi * fsw * L2;
grid_ripple_fraction = abs(Zc_fsw / (Zc_fsw + Zl2_fsw));
grid_ripple_est = delta_i_est * grid_ripple_fraction;

p.lcl = struct();
p.lcl.L1 = L1;
p.lcl.R1 = R1;
p.lcl.Cf = Cf;
p.lcl.Rd = Rd;
p.lcl.L2 = L2;
p.lcl.R2 = R2;
p.lcl.L1_min = L1_min;
p.lcl.Cf_max = Cf_max;
p.lcl.f_res = f_res;
p.lcl.delta_i_est = delta_i_est;
p.lcl.grid_ripple_fraction_fsw = grid_ripple_fraction;
p.lcl.grid_ripple_est_fsw = grid_ripple_est;

assignin('base', 'p', p);

fprintf('LCL design:\n');
fprintf('  L1 = %.3g H, R1 = %.3g Ohm\n', p.lcl.L1, p.lcl.R1);
fprintf('  Cf = %.3g F, Rd = %.3g Ohm\n', p.lcl.Cf, p.lcl.Rd);
fprintf('  L2 = %.3g H, R2 = %.3g Ohm\n', p.lcl.L2, p.lcl.R2);
fprintf('  fres = %.1f Hz, estimated converter ripple = %.2f A p-p\n', p.lcl.f_res, p.lcl.delta_i_est);
