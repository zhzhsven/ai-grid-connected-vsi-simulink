function grid_converter_control_sfun(block)
%GRID_CONVERTER_CONTROL_SFUN dq current control, SRF-PLL, SPWM, and dead time.
%
% Dialog parameter:
%   p - parameter structure created by inv_params_init/design/tune scripts.

setup(block);

function setup(block)
p = getParams(block);

block.NumDialogPrms = 1;
block.NumInputPorts = 2;
block.NumOutputPorts = 5;

block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;

for k = 1:2
    block.InputPort(k).Dimensions = 3;
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real';
    block.InputPort(k).DirectFeedthrough = false;
    block.InputPort(k).SamplingMode = 'Sample';
end

outDims = [6, 4, 2, 3, 4];
for k = 1:5
    block.OutputPort(k).Dimensions = outDims(k);
    block.OutputPort(k).DatatypeID = 0;
    block.OutputPort(k).Complexity = 'Real';
    block.OutputPort(k).SamplingMode = 'Sample';
end

block.SampleTimes = [p.sim.TsGate 0];
block.SimStateCompliance = 'DefaultSimState';

block.RegBlockMethod('PostPropagationSetup', @postPropagationSetup);
block.RegBlockMethod('InitializeConditions', @initializeConditions);
block.RegBlockMethod('Outputs', @outputs);
block.RegBlockMethod('Update', @update);

function postPropagationSetup(block)
names = {'theta', 'omega', 'pllInt', 'idInt', 'iqInt', ...
    'dq', 'pll', 'vabcCmd', 'mabc', 'gates', ...
    'activeSide', 'pendingSide', 'deadCounter', 'ctrlCounter', 'carrier'};
dims = [1, 1, 1, 1, 1, 4, 2, 3, 3, 6, 3, 3, 3, 1, 1];

block.NumDworks = numel(names);
for k = 1:numel(names)
    block.Dwork(k).Name = names{k};
    block.Dwork(k).Dimensions = dims(k);
    block.Dwork(k).DatatypeID = 0;
    block.Dwork(k).Complexity = 'Real';
    block.Dwork(k).UsedAsDiscState = true;
end

function initializeConditions(block)
p = getParams(block);

block.Dwork(1).Data = 0;
block.Dwork(2).Data = p.pll.omegaNom;
block.Dwork(3).Data = 0;
block.Dwork(4).Data = 0;
block.Dwork(5).Data = 0;
block.Dwork(6).Data = [p.ref.idHigh; p.ref.iq; 0; 0];
block.Dwork(7).Data = [0; p.grid.freq];
block.Dwork(8).Data = [0; 0; 0];
block.Dwork(9).Data = [0; 0; 0];
block.Dwork(10).Data = zeros(6, 1);
block.Dwork(11).Data = zeros(3, 1);
block.Dwork(12).Data = zeros(3, 1);
block.Dwork(13).Data = zeros(3, 1);
block.Dwork(14).Data = 0;
block.Dwork(15).Data = 0;

function outputs(block)
block.OutputPort(1).Data = block.Dwork(10).Data;
block.OutputPort(2).Data = block.Dwork(6).Data;
block.OutputPort(3).Data = block.Dwork(7).Data;
block.OutputPort(4).Data = block.Dwork(8).Data;
block.OutputPort(5).Data = [block.Dwork(9).Data; block.Dwork(15).Data];

function update(block)
p = getParams(block);

t = block.CurrentTime;
iabc = block.InputPort(1).Data(:);
vabc = block.InputPort(2).Data(:);

theta = block.Dwork(1).Data;
omega = block.Dwork(2).Data;
pllInt = block.Dwork(3).Data;
idInt = block.Dwork(4).Data;
iqInt = block.Dwork(5).Data;
ctrlCounter = block.Dwork(14).Data;

if t > 0
    theta = wrapTwoPi(theta + omega * p.sim.TsGate);
end

if ctrlCounter <= 0
    [vdGrid, vqGrid] = abcToDq(vabc, theta);

    pllErr = vqGrid;
    pllInt = clamp(pllInt + p.pll.Ki * pllErr * p.pll.Ts, ...
        p.pll.omegaMin - p.pll.omegaNom, p.pll.omegaMax - p.pll.omegaNom);
    omegaUnsat = p.pll.omegaNom + p.pll.Kp * pllErr + pllInt;
    omega = clamp(omegaUnsat, p.pll.omegaMin, p.pll.omegaMax);

    [id, iq] = abcToDq(iabc, theta);
    if t < p.ref.stepTime
        idRef = p.ref.idHigh;
    else
        idRef = p.ref.idLow;
    end
    iqRef = p.ref.iq;

    ed = idRef - id;
    eq = iqRef - iq;

    idInt = clamp(idInt + p.ctrl.Ki * ed * p.ctrl.Ts, ...
        -p.ctrl.integratorLimit, p.ctrl.integratorLimit);
    iqInt = clamp(iqInt + p.ctrl.Ki * eq * p.ctrl.Ts, ...
        -p.ctrl.integratorLimit, p.ctrl.integratorLimit);

    ud = p.ctrl.Kp * ed + idInt;
    uq = p.ctrl.Kp * eq + iqInt;

    vdCmd = vdGrid + ud - omega * p.ctrl.Leq * iq;
    vqCmd = vqGrid + uq + omega * p.ctrl.Leq * id;

    vMag = hypot(vdCmd, vqCmd);
    if vMag > p.ctrl.Vmax
        scale = p.ctrl.Vmax / vMag;
        vdCmd = vdCmd * scale;
        vqCmd = vqCmd * scale;
    end

    vabcCmd = dqToAbc(vdCmd, vqCmd, theta);
    mabc = clamp(2 * vabcCmd / p.dc.Vdc, -p.switch.mMax, p.switch.mMax);

    block.Dwork(6).Data = [idRef; iqRef; id; iq];
    block.Dwork(7).Data = [theta; omega / (2 * pi)];
    block.Dwork(8).Data = vabcCmd;
    block.Dwork(9).Data = mabc;
    block.Dwork(3).Data = pllInt;
    block.Dwork(4).Data = idInt;
    block.Dwork(5).Data = iqInt;

    ctrlCounter = max(1, round(p.sim.TsCtrl / p.sim.TsGate)) - 1;
else
    ctrlCounter = ctrlCounter - 1;
    mabc = block.Dwork(9).Data;
end

carrier = triangleCarrier(t, p.switch.fsw);
desiredUpper = mabc(:) >= carrier;
gates = applyDeadTime(block, desiredUpper, p.ctrl.deadSteps);

block.Dwork(1).Data = theta;
block.Dwork(2).Data = omega;
block.Dwork(10).Data = gates;
block.Dwork(14).Data = ctrlCounter;
block.Dwork(15).Data = carrier;

function gates = applyDeadTime(block, desiredUpper, deadSteps)
activeSide = block.Dwork(11).Data;
pendingSide = block.Dwork(12).Data;
deadCounter = block.Dwork(13).Data;
gates = zeros(6, 1);

for phase = 1:3
    desiredSide = 2 * double(desiredUpper(phase)) - 1;
    active = activeSide(phase);
    pending = pendingSide(phase);
    count = deadCounter(phase);

    if pending ~= 0
        if desiredSide ~= pending
            pending = desiredSide;
            count = deadSteps;
            active = 0;
        elseif count > 0
            count = count - 1;
            active = 0;
        else
            active = pending;
            pending = 0;
        end
    elseif desiredSide ~= active
        pending = desiredSide;
        count = deadSteps;
        active = 0;
    end

    if active > 0
        gates(2 * phase - 1) = getGateHigh(block);
    elseif active < 0
        gates(2 * phase) = getGateHigh(block);
    end

    activeSide(phase) = active;
    pendingSide(phase) = pending;
    deadCounter(phase) = count;
end

block.Dwork(11).Data = activeSide;
block.Dwork(12).Data = pendingSide;
block.Dwork(13).Data = deadCounter;

function [d, q] = abcToDq(abc, theta)
angles = [theta; theta - 2 * pi / 3; theta + 2 * pi / 3];
d = (2 / 3) * sum(abc(:) .* cos(angles));
q = -(2 / 3) * sum(abc(:) .* sin(angles));

function abc = dqToAbc(d, q, theta)
angles = [theta; theta - 2 * pi / 3; theta + 2 * pi / 3];
abc = d * cos(angles) - q * sin(angles);

function y = triangleCarrier(t, fsw)
phase = mod(t * fsw, 1);
y = 4 * abs(phase - 0.5) - 1;

function y = wrapTwoPi(x)
y = mod(x, 2 * pi);

function y = clamp(x, xmin, xmax)
y = min(max(x, xmin), xmax);

function p = getParams(block)
try
    p = block.DialogPrm(1).Data;
catch
    p = evalin('base', 'p');
end

function gateHigh = getGateHigh(block)
p = getParams(block);
gateHigh = p.switch.gateHigh;
