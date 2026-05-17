%TUNE_DQ_PLL_CONTROLLERS Conservative dq current-loop and SRF-PLL tuning.

if ~exist('p', 'var') || ~isfield(p, 'lcl')
    run(fullfile(fileparts(mfilename('fullpath')), 'inv_params_init.m'));
    run(fullfile(fileparts(mfilename('fullpath')), 'design_lcl_filter.m'));
end

Leq = p.lcl.L1 + p.lcl.L2;
Req = p.lcl.R1 + p.lcl.R2;

% Keep the current loop comfortably below the LCL resonance.
f_ci = 400;                        % Hz
w_ci = 2 * pi * f_ci;

p.ctrl = struct();
p.ctrl.Ts = p.sim.TsCtrl;
p.ctrl.deadTime = p.switch.deadTime;
p.ctrl.deadSteps = max(1, round(p.switch.deadTime / p.sim.TsGate));
p.ctrl.Leq = Leq;
p.ctrl.Req = Req;
p.ctrl.f_bw = f_ci;
p.ctrl.Kp = Leq * w_ci;
p.ctrl.Ki = Req * w_ci;
p.ctrl.Vmax = p.switch.mMax * p.dc.Vdc / 2;
p.ctrl.integratorLimit = p.ctrl.Vmax;

% SRF-PLL small-signal tuning. vq ~= Vphase_peak * angle_error.
f_pll = 30;                        % Hz
zeta_pll = 0.707;
w_pll = 2 * pi * f_pll;
Vpll = p.grid.Vphase_peak;

p.pll = struct();
p.pll.Ts = p.sim.TsCtrl;
p.pll.f_bw = f_pll;
p.pll.zeta = zeta_pll;
p.pll.Kp = 2 * zeta_pll * w_pll / Vpll;
p.pll.Ki = w_pll^2 / Vpll;
p.pll.omegaNom = p.grid.omega;
p.pll.omegaMin = 2 * pi * 45;
p.pll.omegaMax = 2 * pi * 55;

p.ref = struct();
p.ref.idHigh = p.spec.IAC_ref_high;
p.ref.idLow = p.spec.IAC_ref_low;
p.ref.iq = 0;
p.ref.stepTime = p.spec.tStep;

assignin('base', 'p', p);

fprintf('Controller tuning:\n');
fprintf('  Current PI: Kp = %.4g, Ki = %.4g, bandwidth = %.0f Hz\n', p.ctrl.Kp, p.ctrl.Ki, p.ctrl.f_bw);
fprintf('  SRF-PLL PI: Kp = %.4g, Ki = %.4g, bandwidth = %.0f Hz\n', p.pll.Kp, p.pll.Ki, p.pll.f_bw);
