# Original AI Engineering Prompt

This file records the original prompt used to generate the baseline Simulink model with Codex and MATLAB/Simulink MCP tools.

## Prompt

```text
Create a three-phase grid-connected DC-AC converter model in Simulink using Simscape Electrical.

Use MATLAB R2026a and the available MATLAB/Simulink MCP tools. Save all generated files in the current project folder.

Model requirements:
- Three-phase two-level voltage source inverter
- Ideal DC voltage source on the DC side
- Switching model, not averaged model
- SPWM modulation 
- Dead time = 2 us
- LCL filter between inverter and grid
- Three-phase grid voltage source
- dq-frame closed-loop current control
- SRF-PLL for grid synchronization

Design specifications:
- Grid phase-voltage amplitude: VAC = 240 V
- AC current reference amplitude: IAC_ref = 30 A
- AC fundamental frequency: fAC = 50 Hz
- TAC = 1 / fAC
- Switching frequency: fsw = 20 kHz
- Converter-side current ripple: Δis ≤ 3 A
- Grid-side current harmonic amplitude: Ih ≤ 5% of IAC_ref for h ≥ 2
- Simulation time: around 0.5 s

Dynamic test:
- Apply a step change to the current reference:
  IAC_ref = 30 A → 15 A
- Apply the step after the initial transient, for example at t = 0.25 s
- Evaluate the transient response, settling behavior, and current tracking.

Please generate:
1. A parameter initialization script
2. An LCL filter design script
3. A dq current controller and PLL tuning script
4. The Simulink switching model
5. A simulation script
6. A result analysis script

Please report and plot:
- Three-phase grid voltages
- Three-phase grid currents
- dq current references and measured dq currents
- PLL frequency and angle
- Converter-side current ripple
- Grid-side current harmonic spectrum
- THD or harmonic amplitudes
- Step response from 30 A to 15 A

Important:
- Do not use transfer-function or averaged inverter approximations.
- First summarize the chosen LCL filter, controller, PLL, and sampling assumptions before editing the model.
- If any specification is ambiguous, make a reasonable engineering assumption and state it explicitly.

Important clarification:
Only the power stage/inverter must remain a switching model.

The controller implementation does NOT need to be a switching-level model.
You may implement the dq controller, PLL, and modulation using:
- discrete PI blocks,
- MATLAB Function blocks,
- averaged control equations,
- standard Simulink control logic.

The “no averaged model” requirement only applies to the inverter power stage itself.

For the first iteration, focus on building a correct and stable baseline model that satisfies the specifications reasonably well.
Do not perform aggressive automatic optimization unless explicitly requested later.
```
