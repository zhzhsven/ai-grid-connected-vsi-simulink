%RUN_SIMULATION Build if needed, then run the switching model.

run(fullfile(fileparts(mfilename('fullpath')), 'inv_params_init.m'));
run(fullfile(fileparts(mfilename('fullpath')), 'design_lcl_filter.m'));
run(fullfile(fileparts(mfilename('fullpath')), 'tune_dq_pll_controllers.m'));

if ~isfile(p.files.model)
    run(fullfile(p.scriptDir, 'build_three_phase_grid_converter_model.m'));
end

in = Simulink.SimulationInput(p.modelName);
in = in.setModelParameter('StopTime', num2str(p.sim.tStop));
in = in.setModelParameter('MaxStep', num2str(p.sim.maxStep));
in = in.setVariable('p', p);

fprintf('Running %s for %.3f s. This switching Simscape run can take a while.\n', p.modelName, p.sim.tStop);
out = sim(in);

save(p.files.simData, 'out', 'p', '-v7.3');
fprintf('Saved simulation results to %s\n', p.files.simData);
