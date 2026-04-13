# content

So we have several mono-repos added to the workspace

- mono-repo (the place where I want to make changes)

## These are examples. Likely not going to change code here (Yet)

- build (uses pkg:mono_repo)
- shelf (uses pkg:mono_repo)
- tools

# Important working

So there is the general notion of a "mono-repo" – in the Dart/Flutter world this is where we have one (usually GitHub) repository which has more than one
package. 

`mono_repo` or `pkg:mono_repo` is the name of a package we're trying to improve – that's what we're trying to improve.

Be careful as we talk to be make sure we're clear about what we're talking about - because we want to improve the ability of `mono_repo` to support mono-repos.

okay?

# history

pkg:mono_repo has a LOT of ugly history about supporting efficient configuration for old Travis-CI where spinning up
a "worker" was really expensive

# Current story - with mono-repo

- repos like `build` and `shelf` use mono-repo now.
- The generated actions are VERY complex - because they were trying to minimize the number of runners

# Current story - without mono-repo

Look at `tools` repository in this workspace - it has a bunch of packages in a mono-repo.
It has a BUNCH of hand-rolled, one-off actions that repeat a LOT across each.
They do have some logic to make sure we only run CI for a package when that package changes – which is GREAT

# New story - brainstorm

- I'd love to make mono_repo MUCH more simple.
- I'd love to make it easy for folks to configure their CI (like in my_pkg/mono_pkg.yaml) right next to their pubspec (my_pkg/pubspec.yaml)
- I LOVE the `pubspec` notion of defining an SDK version to test on (so it automatically tests on the oldest supported version)
- I'd love to allow an entire repo to just define defaults for all packages – so we don't have to configure each package if we want
- I'd love to support dart "workspaces" where if I change a pkg_a and pkg_b depends on pkg_a (via the workspace config) then we automatically test pkg_a and pkg_b (but not unrelated pkg_c) when there is a change.

There are my initial thoughts.

Feel free to create a new document (.md file) so we can run with these ideas and make a plan!

I'm not too worried about trivial breaking changes for the existing behavior as long as it's easy to document for users.
