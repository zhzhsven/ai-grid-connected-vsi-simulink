%ANALYZE_RESULTS Plot and quantify the switching VSI simulation results.

run(fullfile(fileparts(mfilename('fullpath')), 'inv_params_init.m'));
run(fullfile(fileparts(mfilename('fullpath')), 'design_lcl_filter.m'));
run(fullfile(fileparts(mfilename('fullpath')), 'tune_dq_pll_controllers.m'));

if ~isfile(p.files.simData)
    run(fullfile(p.scriptDir, 'run_simulation.m'));
else
    load(p.files.simData, 'out', 'p');
end

if ~isfolder(p.files.figureDir)
    mkdir(p.files.figureDir);
end

vGrid = getTs(out, 'v_grid_abc');
iGrid = getTs(out, 'i_grid_abc');
iConv = getTs(out, 'i_conv_abc');
dq = getTs(out, 'dq_signals');
pll = getTs(out, 'pll_signals');
ctrl = getTs(out, 'ctrl_debug');

fig1 = figure('Name', 'Grid abc voltage and current');
tiledlayout(fig1, 2, 1);
nexttile;
plot(vGrid.Time, vGrid.Data, 'LineWidth', 0.8);
grid on;
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Three-phase grid voltages');
legend('v_a', 'v_b', 'v_c');
nexttile;
plot(iGrid.Time, iGrid.Data, 'LineWidth', 0.8);
grid on;
xlabel('Time (s)');
ylabel('Current (A)');
title('Three-phase grid currents');
legend('i_a', 'i_b', 'i_c');
saveas(fig1, fullfile(p.files.figureDir, 'grid_abc_voltage_current.png'));

fig2 = figure('Name', 'dq current tracking');
plot(dq.Time, dq.Data(:, 1), 'k--', dq.Time, dq.Data(:, 3), 'b', ...
    dq.Time, dq.Data(:, 2), 'r--', dq.Time, dq.Data(:, 4), 'm', ...
    'LineWidth', 0.9);
grid on;
xlabel('Time (s)');
ylabel('Current (A)');
title('dq current references and measured currents');
legend('i_d^*', 'i_d', 'i_q^*', 'i_q');
saveas(fig2, fullfile(p.files.figureDir, 'dq_current_tracking.png'));

fig3 = figure('Name', 'PLL frequency and angle');
tiledlayout(fig3, 2, 1);
nexttile;
plot(pll.Time, pll.Data(:, 2), 'LineWidth', 0.9);
grid on;
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title('PLL frequency');
nexttile;
plot(pll.Time, pll.Data(:, 1), 'LineWidth', 0.9);
grid on;
xlabel('Time (s)');
ylabel('Angle (rad)');
title('PLL angle');
saveas(fig3, fullfile(p.files.figureDir, 'pll_frequency_angle.png'));

rippleWindow = [0.20, 0.24];
ripple = estimateRipple(iConv, p, rippleWindow);

fftWindow = [0.35, min(p.sim.tStop, 0.49)];
harm = harmonicSpectrum(iGrid, p, fftWindow, 50);

step = stepMetrics(dq, p);

fig4 = figure('Name', 'Converter-side ripple');
idx = iConv.Time >= rippleWindow(1) & iConv.Time <= rippleWindow(2);
plot(iConv.Time(idx), iConv.Data(idx, 1), 'b', ...
    ripple.time, ripple.fundamentalA, 'k--', ...
    ripple.time, ripple.residualA, 'r', ...
    'LineWidth', 0.8);
grid on;
xlabel('Time (s)');
ylabel('Current (A)');
title('Converter-side phase-A ripple estimate');
legend('i_{conv,a}', '50 Hz fit', 'HF residual');
saveas(fig4, fullfile(p.files.figureDir, 'converter_side_ripple.png'));

fig5 = figure('Name', 'Grid current harmonic spectrum');
bar(harm.orders, harm.amplitudesA, 0.7);
grid on;
xlabel('Harmonic order');
ylabel('Amplitude (A peak)');
title(sprintf('Grid current harmonics, THD = %.2f %%', 100 * harm.THD));
xlim([1, min(50, max(harm.orders))]);
saveas(fig5, fullfile(p.files.figureDir, 'grid_current_harmonics.png'));

fig6 = figure('Name', 'Current reference step response');
idx = dq.Time >= (p.ref.stepTime - 0.05) & dq.Time <= (p.ref.stepTime + 0.12);
plot(dq.Time(idx), dq.Data(idx, 1), 'k--', dq.Time(idx), dq.Data(idx, 3), 'b', 'LineWidth', 1.0);
grid on;
xlabel('Time (s)');
ylabel('d-axis current (A)');
title('Step response from 30 A to 15 A');
legend('i_d^*', 'i_d');
saveas(fig6, fullfile(p.files.figureDir, 'current_step_response.png'));

analysis = struct();
analysis.ripple = ripple;
analysis.harmonics = harm;
analysis.step = step;
analysis.ctrlDebug = ctrl;

save(p.files.analysis, 'analysis', 'p');
writeReport(p, analysis);

fprintf('Analysis complete. Report: %s\n', p.files.report);
fprintf('  Converter-side ripple estimate: %.3f A p-p\n', ripple.peakToPeakA);
fprintf('  Grid current THD estimate: %.3f %%\n', 100 * harm.THD);
fprintf('  Filtered 5%% step settling estimate: %.4f s\n', step.settlingTime);

function ts = getTs(out, name)
ts = out.get(name);
if isa(ts, 'timeseries')
    return;
end
error('Simulation output "%s" was not found as a timeseries.', name);
end

function ripple = estimateRipple(iConv, p, window)
idx = iConv.Time >= window(1) & iConv.Time <= window(2);
t = iConv.Time(idx);
x = iConv.Data(idx, 1);
[fund, residual] = fitFundamental(t, x, p.grid.freq);

samplesPerSwitch = max(4, round(p.switch.Tsw / median(diff(t))));
nPeriods = floor(numel(residual) / samplesPerSwitch);
pp = zeros(nPeriods, 1);
for k = 1:nPeriods
    range = (k - 1) * samplesPerSwitch + (1:samplesPerSwitch);
    pp(k) = max(residual(range)) - min(residual(range));
end

ripple = struct();
ripple.window = window;
ripple.time = t;
ripple.fundamentalA = fund;
ripple.residualA = residual;
ripple.peakToPeakA = max(pp);
ripple.meanPeakToPeakA = mean(pp);
ripple.meetsSpec = ripple.peakToPeakA <= p.spec.delta_i_max;
end

function harm = harmonicSpectrum(iGrid, p, window, maxOrder)
fs = 1 / p.sim.TsGate;
tUniform = (window(1):1 / fs:window(2)).';
x = interp1(iGrid.Time, iGrid.Data(:, 1), tUniform, 'linear', 'extrap');
x = x - mean(x);
w = hann(numel(x), 'periodic');
X = fft(x .* w);
freq = (0:numel(X)-1).' * fs / numel(X);
amp = 2 * abs(X) / sum(w);

orders = (1:maxOrder).';
amplitudes = zeros(size(orders));
for k = 1:numel(orders)
    [~, idx] = min(abs(freq - orders(k) * p.grid.freq));
    amplitudes(k) = amp(idx);
end

harm = struct();
harm.window = window;
harm.orders = orders;
harm.amplitudesA = amplitudes;
harm.fundamentalA = amplitudes(1);
harm.THD = sqrt(sum(amplitudes(2:end).^2)) / max(amplitudes(1), eps);
harm.limitA = p.spec.grid_harmonic_limit;
harm.maxHarmonicA_h2plus = max(amplitudes(2:end));
harm.meetsHarmonicSpec = all(amplitudes(2:end) <= harm.limitA);
end

function step = stepMetrics(dq, p)
t = dq.Time;
id = dq.Data(:, 3);
final = p.ref.idLow;
rawTol2 = 0.02 * abs(final);
idxAfter = find(t >= p.ref.stepTime);
rawSettlingTime2 = NaN;
for n = idxAfter(:).'
    if all(abs(id(n:end) - final) <= rawTol2)
        rawSettlingTime2 = t(n) - p.ref.stepTime;
        break;
    end
end

dt = median(diff(t));
filterSamples = max(1, round(0.002 / dt));
idFiltered = movmean(id, filterSamples);
filteredTol5 = 0.05 * abs(final);
filteredSettlingTime5 = NaN;
for n = idxAfter(:).'
    if all(abs(idFiltered(n:end) - final) <= filteredTol5)
        filteredSettlingTime5 = t(n) - p.ref.stepTime;
        break;
    end
end

window = t >= p.ref.stepTime & t <= min(p.sim.tStop, p.ref.stepTime + 0.1);
finalWindow = t >= max(p.ref.stepTime, p.sim.tStop - 0.05);
step = struct();
step.finalReferenceA = final;
step.rawTolerance2pctA = rawTol2;
step.rawSettlingTime2pct = rawSettlingTime2;
step.filteredTolerance5pctA = filteredTol5;
step.filteredSettlingTime5pct = filteredSettlingTime5;
step.settlingTime = filteredSettlingTime5;
step.minCurrentA = min(id(window));
step.maxCurrentA = max(id(window));
step.finalMeanA = mean(id(finalWindow));
step.finalStdA = std(id(finalWindow));
step.filteredFinalRangeA = max(idFiltered(finalWindow)) - min(idFiltered(finalWindow));
end

function [fund, residual] = fitFundamental(t, x, f0)
A = [sin(2 * pi * f0 * t), cos(2 * pi * f0 * t), ones(size(t))];
c = A \ x;
fund = A * c;
residual = x - fund;
end

function writeReport(p, analysis)
fid = fopen(p.files.report, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Three-phase grid-connected VSI baseline analysis\n');
fprintf(fid, 'Generated: %s\n\n', char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")));
fprintf(fid, 'Assumptions\n');
fprintf(fid, '  VAC and IAC_ref are phase peak amplitudes.\n');
fprintf(fid, '  Power stage is a detailed switching Simscape Electrical converter.\n');
fprintf(fid, '  Controller and PLL are discrete control logic at %.3g s.\n\n', p.sim.TsCtrl);
fprintf(fid, 'LCL filter\n');
fprintf(fid, '  L1 = %.6g H, R1 = %.6g Ohm\n', p.lcl.L1, p.lcl.R1);
fprintf(fid, '  Cf = %.6g F, Rd = %.6g Ohm\n', p.lcl.Cf, p.lcl.Rd);
fprintf(fid, '  L2 = %.6g H, R2 = %.6g Ohm\n', p.lcl.L2, p.lcl.R2);
fprintf(fid, '  fres = %.2f Hz\n', p.lcl.f_res);
fprintf(fid, '  Estimated design ripple = %.3f A p-p\n\n', p.lcl.delta_i_est);
fprintf(fid, 'Controller and PLL\n');
fprintf(fid, '  Current PI Kp = %.6g, Ki = %.6g, bandwidth = %.2f Hz\n', p.ctrl.Kp, p.ctrl.Ki, p.ctrl.f_bw);
fprintf(fid, '  PLL PI Kp = %.6g, Ki = %.6g, bandwidth = %.2f Hz\n\n', p.pll.Kp, p.pll.Ki, p.pll.f_bw);
fprintf(fid, 'Measured analysis\n');
fprintf(fid, '  Converter-side phase-A ripple = %.4f A p-p, meets spec = %d\n', ...
    analysis.ripple.peakToPeakA, analysis.ripple.meetsSpec);
fprintf(fid, '  Grid current fundamental = %.4f A peak\n', analysis.harmonics.fundamentalA);
fprintf(fid, '  Grid current THD = %.4f %%\n', 100 * analysis.harmonics.THD);
fprintf(fid, '  Max h>=2 harmonic = %.4f A peak, limit = %.4f A peak, meets spec = %d\n', ...
    analysis.harmonics.maxHarmonicA_h2plus, analysis.harmonics.limitA, analysis.harmonics.meetsHarmonicSpec);
fprintf(fid, '  Raw 2%% step settling time = %.6g s\n', analysis.step.rawSettlingTime2pct);
fprintf(fid, '  2 ms moving-average 5%% step settling time = %.6g s\n', analysis.step.filteredSettlingTime5pct);
fprintf(fid, '  Final id mean/std over last 50 ms = %.4f / %.4f A\n', ...
    analysis.step.finalMeanA, analysis.step.finalStdA);
fprintf(fid, '  Step min/max id in first 100 ms = %.4f / %.4f A\n', ...
    analysis.step.minCurrentA, analysis.step.maxCurrentA);
clear cleanup;
end
