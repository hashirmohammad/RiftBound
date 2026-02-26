import os
import sys

env = SConscript("extern/godot-cpp/SConstruct")

# Add source files
env.Append(CPPPATH=["src/"])

sources = Glob("src/*.cpp") + Glob("src/card/*.cpp")

# Output the compiled library into bin/
if env["platform"] == "macos":
    library = env.SharedLibrary(
        "bin/libriftbound.{}.{}.framework/libriftbound.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "bin/libriftbound{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)