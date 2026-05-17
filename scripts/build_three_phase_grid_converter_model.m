%BUILD_THREE_PHASE_GRID_CONVERTER_MODEL Create the Simscape switching model.

run(fullfile(fileparts(mfilename('fullpath')), 'inv_params_init.m'));
run(fullfile(fileparts(mfilename('fullpath')), 'design_lcl_filter.m'));
run(fullfile(fileparts(mfilename('fullpath')), 'tune_dq_pll_controllers.m'));

mdl = p.modelName;
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end

load_system('simulink');
load_system('ee_lib');
load_system('fl_lib');
load_system('nesl_utility');

new_system(mdl);
open_system(mdl);

set_param(mdl, ...
    'StopTime', 'p.sim.tStop', ...
    'SolverType', 'Variable-step', ...
    'Solver', p.sim.solver, ...
    'MaxStep', 'p.sim.maxStep', ...
    'RelTol', num2str(p.sim.relTol), ...
    'AbsTol', num2str(p.sim.absTol), ...
    'SignalLogging', 'off');

initFcn = [ ...
    'modelDir = fileparts(get_param(bdroot,''FileName''));' ...
    'projectDir = fileparts(modelDir);' ...
    'scriptDir = fullfile(projectDir,''scripts'');' ...
    'addpath(scriptDir);' ...
    'run(fullfile(scriptDir,''inv_params_init.m''));' ...
    'run(fullfile(scriptDir,''design_lcl_filter.m''));' ...
    'run(fullfile(scriptDir,''tune_dq_pll_controllers.m''));' ...
    ];
set_param(mdl, 'InitFcn', initFcn);

paths = struct();
paths.converter = findLibBlock('ee_lib', 'Converter (Three-Phase)', 'Semiconductors Converters Converters');
paths.gateMux = findLibBlock('ee_lib', 'Six-Pulse Gate Multiplexer', 'Converters');
paths.dcSource = findLibBlock('ee_lib', 'Voltage Source', 'Sources');
paths.gridSource = findLibBlock('ee_lib', 'Voltage Source (Three-Phase)', 'Sources');
paths.rlc3 = findLibBlock('ee_lib', 'RLC (Three-Phase)', 'RLC Assemblies');
paths.iSensor3 = findLibBlock('ee_lib', 'Current Sensor (Three-Phase)', 'Sensors');
paths.vSensor3 = findLibBlock('ee_lib', 'Phase Voltage Sensor (Three-Phase)', 'Sensors');
paths.groundedNeutral = findLibBlock('ee_lib', 'Grounded Neutral (Three-Phase)', 'Connectors References');
paths.elecRef = findLibBlock('ee_lib', 'Electrical Reference', 'References');
paths.ps2sl = findLibBlock('nesl_utility', 'PS-Simulink Converter', '');
paths.sl2ps = findLibBlock('nesl_utility', 'Simulink-PS Converter', '');
paths.solver = findLibBlock('nesl_utility', 'Solver Configuration', '');
paths.level2Sfun = findLibBlock('simulink', 'Level-2 MATLAB S-Function', 'User-Defined Functions');

% Power stage and plant.
add_block(paths.converter, [mdl '/VSI'], 'Position', [260 190 390 310]);
add_block(paths.gateMux, [mdl '/GateMux'], 'Position', [95 190 205 310]);
add_block(paths.dcSource, [mdl '/Ideal_DC_Source'], 'Position', [255 70 390 130]);
add_block(paths.elecRef, [mdl '/Electrical_Reference'], 'Position', [430 95 465 130]);
add_block(paths.solver, [mdl '/Solver_Configuration'], 'Position', [430 145 510 190]);

add_block(paths.iSensor3, [mdl '/Iconv_Sensor'], 'Position', [450 205 525 295]);
add_block(paths.vSensor3, [mdl '/Vinv_Sensor'], 'Position', [430 330 515 400]);
add_block(paths.rlc3, [mdl '/L1_Converter_Side'], 'Position', [575 215 690 285]);
add_block(paths.rlc3, [mdl '/Cf_Damped_Shunt'], 'Position', [700 330 815 400]);
add_block(paths.groundedNeutral, [mdl '/AC_Grounded_Neutral'], 'Position', [835 335 920 395]);
add_block(paths.rlc3, [mdl '/L2_Grid_Side'], 'Position', [750 215 865 285]);
add_block(paths.iSensor3, [mdl '/Igrid_Sensor'], 'Position', [910 205 985 295]);
add_block(paths.vSensor3, [mdl '/Vgrid_Sensor'], 'Position', [1010 330 1095 400]);
add_block(paths.gridSource, [mdl '/Grid_Source'], 'Position', [1040 205 1185 295]);

% Controller, interface, and logging blocks.
add_block(paths.level2Sfun, [mdl '/dq_PLL_SPWM_Controller'], ...
    'Position', [475 455 660 550], ...
    'FunctionName', 'grid_converter_control_sfun', ...
    'Parameters', 'p');
add_block('simulink/Signal Routing/Demux', [mdl '/Gate_Demux'], ...
    'Position', [250 460 280 550], 'Outputs', '6');

gateNames = {'GaH', 'GaL', 'GbH', 'GbL', 'GcH', 'GcL'};
for k = 1:6
    add_block(paths.sl2ps, [mdl '/' gateNames{k} '_SL2PS'], ...
        'Position', [300 440 + 28*k 345 458 + 28*k], ...
        'Unit', 'V', ...
        'FilteringAndDerivatives', 'zero');
end

add_block(paths.ps2sl, [mdl '/Iconv_PS2SL'], 'Position', [465 335 510 365], ...
    'Unit', 'A', 'VectorFormat', '1-D array');
add_block(paths.ps2sl, [mdl '/Vinv_PS2SL'], 'Position', [545 380 590 410], ...
    'Unit', 'V', 'VectorFormat', '1-D array');
add_block(paths.ps2sl, [mdl '/Igrid_PS2SL'], 'Position', [925 430 970 460], ...
    'Unit', 'A', 'VectorFormat', '1-D array');
add_block(paths.ps2sl, [mdl '/Vgrid_PS2SL'], 'Position', [1025 430 1070 460], ...
    'Unit', 'V', 'VectorFormat', '1-D array');

addToWorkspace(mdl, 'v_grid_abc', [1120 430 1215 460]);
addToWorkspace(mdl, 'v_inv_abc', [620 380 715 410]);
addToWorkspace(mdl, 'i_grid_abc', [825 430 920 460]);
addToWorkspace(mdl, 'i_conv_abc', [535 335 630 365]);
addToWorkspace(mdl, 'gate_signals', [135 430 230 460]);
addToWorkspace(mdl, 'dq_signals', [705 460 800 490]);
addToWorkspace(mdl, 'pll_signals', [705 500 800 530]);
addToWorkspace(mdl, 'v_cmd_abc', [705 540 800 570]);
addToWorkspace(mdl, 'ctrl_debug', [705 580 800 610]);

% Configure Simscape Electrical blocks.
set_param([mdl '/VSI'], ...
    'fidelity_option', 'ee.enum.converters.fidelity.detailed', ...
    'device_type', 'ee.enum.converters.switchingdevice.ideal', ...
    'Vgt', num2str(p.switch.Vgt), ...
    'Ron', num2str(p.switch.Ron), ...
    'Goff', num2str(p.switch.Goff), ...
    'diode_param', 'ee.enum.converters.protectiondiode.nodynamics', ...
    'diode_Ron', num2str(p.switch.Ron), ...
    'diode_Goff', num2str(p.switch.Goff));

set_param([mdl '/Ideal_DC_Source'], 'dc_voltage', num2str(p.dc.Vdc));
set_param([mdl '/Grid_Source'], ...
    'vline_rms', num2str(p.grid.Vline_rms, 12), ...
    'freq', num2str(p.grid.freq), ...
    'SShortCircuit', '100e6', ...
    'XR', '10');

set_param([mdl '/L1_Converter_Side'], ...
    'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
    'R', num2str(p.lcl.R1), ...
    'L', num2str(p.lcl.L1));
set_param([mdl '/L2_Grid_Side'], ...
    'component_structure', 'ee.enum.rlc.structure.SeriesRL', ...
    'R', num2str(p.lcl.R2), ...
    'L', num2str(p.lcl.L2));
set_param([mdl '/Cf_Damped_Shunt'], ...
    'component_structure', 'ee.enum.rlc.structure.SeriesRC', ...
    'R', num2str(p.lcl.Rd), ...
    'C', num2str(p.lcl.Cf));

% Physical conserving and physical-signal connections.
connectPhys(mdl, 'Ideal_DC_Source', 'LConn', 1, 'VSI', 'RConn', 1);
connectPhys(mdl, 'Ideal_DC_Source', 'RConn', 1, 'VSI', 'RConn', 2);
connectPhys(mdl, 'Grid_Source', 'LConn', 1, 'Electrical_Reference', 'LConn', 1);
connectPhys(mdl, 'Solver_Configuration', 'RConn', 1, 'Electrical_Reference', 'LConn', 1);

connectPhys(mdl, 'GateMux', 'RConn', 1, 'VSI', 'LConn', 1);
connectPhys(mdl, 'VSI', 'LConn', 2, 'Iconv_Sensor', 'LConn', 1);
connectPhys(mdl, 'VSI', 'LConn', 2, 'Vinv_Sensor', 'LConn', 1);
connectPhys(mdl, 'Vinv_Sensor', 'RConn', 2, 'AC_Grounded_Neutral', 'LConn', 1);
connectPhys(mdl, 'Iconv_Sensor', 'RConn', 2, 'L1_Converter_Side', 'LConn', 1);
connectPhys(mdl, 'L1_Converter_Side', 'RConn', 1, 'L2_Grid_Side', 'LConn', 1);
connectPhys(mdl, 'L1_Converter_Side', 'RConn', 1, 'Cf_Damped_Shunt', 'LConn', 1);
connectPhys(mdl, 'Cf_Damped_Shunt', 'RConn', 1, 'AC_Grounded_Neutral', 'LConn', 1);
connectPhys(mdl, 'L2_Grid_Side', 'RConn', 1, 'Igrid_Sensor', 'LConn', 1);
connectPhys(mdl, 'Igrid_Sensor', 'RConn', 2, 'Grid_Source', 'RConn', 1);
connectPhys(mdl, 'Grid_Source', 'RConn', 1, 'Vgrid_Sensor', 'LConn', 1);
connectPhys(mdl, 'Vgrid_Sensor', 'RConn', 2, 'AC_Grounded_Neutral', 'LConn', 1);

connectPhys(mdl, 'Iconv_Sensor', 'RConn', 1, 'Iconv_PS2SL', 'LConn', 1);
connectPhys(mdl, 'Vinv_Sensor', 'RConn', 1, 'Vinv_PS2SL', 'LConn', 1);
connectPhys(mdl, 'Igrid_Sensor', 'RConn', 1, 'Igrid_PS2SL', 'LConn', 1);
connectPhys(mdl, 'Vgrid_Sensor', 'RConn', 1, 'Vgrid_PS2SL', 'LConn', 1);

for k = 1:6
    connectPhys(mdl, [gateNames{k} '_SL2PS'], 'RConn', 1, 'GateMux', 'LConn', k);
end

% Simulink signal connections.
add_line(mdl, 'Igrid_PS2SL/1', 'dq_PLL_SPWM_Controller/1', 'autorouting', 'on');
add_line(mdl, 'Vgrid_PS2SL/1', 'dq_PLL_SPWM_Controller/2', 'autorouting', 'on');
add_line(mdl, 'dq_PLL_SPWM_Controller/1', 'Gate_Demux/1', 'autorouting', 'on');
add_line(mdl, 'dq_PLL_SPWM_Controller/1', 'gate_signals/1', 'autorouting', 'on');
add_line(mdl, 'dq_PLL_SPWM_Controller/2', 'dq_signals/1', 'autorouting', 'on');
add_line(mdl, 'dq_PLL_SPWM_Controller/3', 'pll_signals/1', 'autorouting', 'on');
add_line(mdl, 'dq_PLL_SPWM_Controller/4', 'v_cmd_abc/1', 'autorouting', 'on');
add_line(mdl, 'dq_PLL_SPWM_Controller/5', 'ctrl_debug/1', 'autorouting', 'on');
add_line(mdl, 'Iconv_PS2SL/1', 'i_conv_abc/1', 'autorouting', 'on');
add_line(mdl, 'Vinv_PS2SL/1', 'v_inv_abc/1', 'autorouting', 'on');
add_line(mdl, 'Igrid_PS2SL/1', 'i_grid_abc/1', 'autorouting', 'on');
add_line(mdl, 'Vgrid_PS2SL/1', 'v_grid_abc/1', 'autorouting', 'on');

for k = 1:6
    add_line(mdl, sprintf('Gate_Demux/%d', k), sprintf('%s_SL2PS/1', gateNames{k}), 'autorouting', 'on');
end

set_param(mdl, 'SimscapeLogType', 'none');
save_system(mdl, p.files.model);
fprintf('Saved switching model to %s\n', p.files.model);

function addToWorkspace(mdl, varName, pos)
add_block('simulink/Sinks/To Workspace', [mdl '/' varName], ...
    'Position', pos, ...
    'VariableName', varName, ...
    'SaveFormat', 'Timeseries', ...
    'MaxDataPoints', 'inf', ...
    'Decimation', '1');
end

function connectPhys(mdl, srcBlock, srcKind, srcIdx, dstBlock, dstKind, dstIdx)
src = get_param([mdl '/' srcBlock], 'PortHandles');
dst = get_param([mdl '/' dstBlock], 'PortHandles');
srcPorts = src.(srcKind);
dstPorts = dst.(dstKind);
add_line(mdl, srcPorts(srcIdx), dstPorts(dstIdx), 'autorouting', 'on');
end

function path = findLibBlock(lib, normalizedName, normalizedParent)
hits = find_system(lib, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'RegExp', 'on', 'Name', '.*');
for k = 1:numel(hits)
    name = normalizeText(get_param(hits{k}, 'Name'));
    parent = normalizeText(get_param(hits{k}, 'Parent'));
    if strcmp(name, normalizedName)
        if isempty(normalizedParent) || contains(parent, normalizedParent)
            path = hits{k};
            return;
        end
    end
end
error('Could not find library block "%s" in %s.', normalizedName, lib);
end

function s = normalizeText(s)
s = strrep(s, '&', '');
s = regexprep(s, '[\\/]', ' ');
s = regexprep(s, '\s+', ' ');
s = strtrim(s);
end
