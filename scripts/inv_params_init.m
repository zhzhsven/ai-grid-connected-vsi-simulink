%INV_PARAMS_INIT Baseline parameters for a grid-connected switching VSI.
% Run this before building or simulating three_phase_grid_vsi_lcl.slx.

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
projectDir = fileparts(scriptDir);
if isempty(projectDir)
    projectDir = pwd;
end
addpath(scriptDir);

p = struct();
p.projectDir = projectDir;
p.scriptDir = scriptDir;
p.modelName = 'three_phase_grid_vsi_lcl';

% User specifications. VAC and IAC_ref are interpreted as phase peak values.
p.spec.VAC = 240;                  % V, phase voltage amplitude
p.spec.IAC_ref_high = 30;          % A, phase current amplitude before step
p.spec.IAC_ref_low = 15;           % A, phase current amplitude after step
p.spec.fAC = 50;                   % Hz
p.spec.TAC = 1 / p.spec.fAC;       % s
p.spec.fsw = 20e3;                 % Hz
p.spec.delta_i_max = 3;            % A peak-to-peak converter-side ripple target
p.spec.grid_harmonic_limit = 0.05 * p.spec.IAC_ref_high;
p.spec.tStep = 0.25;               % s

% Engineering assumptions for the first stable switching baseline.
p.assumptions.phaseAmplitudes = true;
p.assumptions.unityPowerFactor = true;
p.assumptions.controllerUsesGridSideCurrent = true;
p.assumptions.powerStageOnlyIsSwitching = true;

% Electrical base values.
p.grid.Vphase_peak = p.spec.VAC;
p.grid.Vphase_rms = p.grid.Vphase_peak / sqrt(2);
p.grid.Vline_rms = sqrt(3) * p.grid.Vphase_rms;
p.grid.omega = 2 * pi * p.spec.fAC;
p.grid.freq = p.spec.fAC;

% Ideal DC source and switching assumptions.
p.dc.Vdc = 800;                    % V
p.switch.fsw = p.spec.fsw;
p.switch.Tsw = 1 / p.switch.fsw;
p.switch.deadTime = 2e-6;          % s
p.switch.mMax = 0.95;              % SPWM command clamp
p.switch.Ron = 1e-3;               % Ohm
p.switch.Goff = 1e-6;              % 1/Ohm
p.switch.gateHigh = 15;            % V
p.switch.gateLow = 0;              % V
p.switch.Vgt = 6;                  % V, gate threshold

% Simulation timing. The 1 us gate sample resolves the 2 us dead time.
p.sim.tStop = 0.5;                 % s
p.sim.TsGate = 1e-6;               % s
p.sim.TsCtrl = p.switch.Tsw;       % s, one controller update per PWM period
p.sim.maxStep = p.sim.TsGate;
p.sim.solver = 'ode23t';
p.sim.relTol = 1e-4;
p.sim.absTol = 1e-6;

% Output file names.
p.files.model = fullfile(projectDir, 'model', [p.modelName '.slx']);
p.files.simData = fullfile(projectDir, 'docs', 'grid_converter_sim_results.mat');
p.files.analysis = fullfile(projectDir, 'docs', 'grid_converter_analysis.mat');
p.files.report = fullfile(projectDir, 'docs', 'grid_converter_analysis_report.txt');
p.files.figureDir = fullfile(projectDir, 'figures');

assignin('base', 'p', p);

fprintf('Initialized %s parameters in p. VAC and IAC_ref are phase peak values.\n', p.modelName);
