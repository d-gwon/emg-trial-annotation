function [rmv_trigger, n_trial] = DE_repeat_trigger_remove(trigger)
%%
%%
    rmv_trigger = trigger;
    for len = length(trigger):-1:2
        if trigger(len) == trigger(len-1)
            rmv_trigger(len) = 0;
        end
    end
    n_trial = [find(rmv_trigger) rmv_trigger(find(rmv_trigger))];
end