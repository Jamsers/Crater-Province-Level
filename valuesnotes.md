Horizon is normally calculated with some [Pythagorean theorem stuff](https://en.wikipedia.org/wiki/Horizon#Distance_to_the_horizon) (i.e. at 100 m, the horizon is 36 km)

However game worlds are flat, so fogless horizon is a lot more straightforward in games. For Godot it's just highest height you expect your player to be, multiplied by 200. (i.e. at 100 m, the horizon is 20 km)

Your far clip should be set to that, and whatever infinite water system you have should render that far.

for the torches - use the values for a Pressurized Kerosene Lamp, because an actual torch only gets up to 50 lumens and it's too dim for my liking

for level design affordances for the GI system - i've tried to make sure that walls are around 30 cm thick (to prevent leaking). I've tried to make sure that lights are around 50 cm away from the nearast wall (so that it doesn't get "swallowed" by the voxelization or whatever). These strike me as fairly generous affordances for the GI system, so that any GI failures in the project are the fault of the GI system itself, and not the fault of the level design.