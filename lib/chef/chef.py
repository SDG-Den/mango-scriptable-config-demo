import re
import sys

src = open(sys.argv[1]).read()

ingredients_src = src.split("Ingredients.", 1)[1].split("Method.", 1)[0]
method_src = src.split("Method.", 1)[1]

values = {}
for line in ingredients_src.splitlines():
    m = re.match(
        r'^\s*(\d+(?:/\d+)?)\s+\S+\s+(.+?)\s+(?:"(.+)"|(-?\d+))\s*$', line
    )
    if m:
        name = m.group(2).strip().lower()
        values[name] = m.group(3) if m.group(3) is not None else int(m.group(4))

bowl = []
dish = []

FLAVOR = {
    "stir",
    "fold",
    "simmer",
    "refrigerate",
    "liquefy",
    "knead",
    "rest",
    "sift",
    "whip",
    "season",
    "baste",
    "garnish",
    "taste",
    "adjust",
}


def resolve(arg):
    arg = arg.strip()
    if arg.startswith('"'):
        return arg[1:-1]
    key = arg.lower()
    while key.startswith("the "):
        key = key[4:]
    if key in values:
        return values[key]
    try:
        return int(key)
    except ValueError:
        raise ValueError("unknown ingredient: %s" % arg)


def finish(line):
    return re.sub(r"\.$", "", re.sub(r"#.*", "", line)).strip()


def action_of(line):
    line = finish(line)
    if not line:
        return "nop", None
    low = line.lower()

    first = low.split()[0]
    if first in FLAVOR:
        return "nop", None
    if low.startswith("serves"):
        return "serves", None
    if low.startswith("serve"):
        return "serve", None
    if "pour contents of the baking dish into the mixing bowl" in low:
        return "pour_in", None
    if "pour contents of the mixing bowl into the baking dish" in low:
        return "pour_out", None
    if low.startswith("clean") or low.startswith("empty"):
        return "clean", None

    m = re.search(r"put\s+(.+?)\s+into the mixing bowl", low)
    if m:
        return "push", resolve(low[m.start(1):m.end(1)])
    m = re.search(r"add\s+(.+?)\s+to the mixing bowl", low)
    if m:
        return "push", resolve(low[m.start(1):m.end(1)])
    if first in ("combine", "mix"):
        return "combine", None
    m = re.search(r"divide\s+(.+)", low)
    if m:
        return "divide", resolve(low[m.start(1):m.end(1)])
    m = re.search(r"subtract\s+(.+)", low)
    if m:
        return "subtract", resolve(low[m.start(1):m.end(1)])
    m = re.search(r"multiply\s+(.+)", low)
    if m:
        return "multiply", resolve(low[m.start(1):m.end(1)])
    return "nop", None


def run(action):
    kind, arg = action
    if kind == "push":
        bowl.append(arg)
    elif kind == "pour_out":
        dish.extend(bowl)
        bowl[:] = []
    elif kind == "pour_in":
        bowl.extend(dish)
        dish[:] = []
    elif kind == "combine":
        b = bowl.pop()
        a = bowl.pop()
        bowl.append(a + b)
    elif kind == "divide":
        b = bowl.pop()
        a = bowl.pop()
        bowl.append(a // arg)
    elif kind == "subtract":
        b = bowl.pop()
        a = bowl.pop()
        bowl.append(a - arg)
    elif kind == "multiply":
        b = bowl.pop()
        a = bowl.pop()
        bowl.append(a * arg)
    elif kind == "clean":
        bowl[:] = []
        dish[:] = []
    elif kind == "serve":
        print("".join(s if isinstance(s, str) else chr(s) for s in dish), flush=True)
        dish[:] = []


for raw in method_src.splitlines():
    run(action_of(raw))