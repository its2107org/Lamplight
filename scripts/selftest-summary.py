import json, sys
d = json.load(open(sys.argv[1]))
print("Pieces: %s  text: %s  pdf: %s  original page: %s" % (d["pieces"], d["text"], d["pdf"], d["originalPage"]))
for r in d["results"]:
    print("  night %2d %-5s %-13s %6s  %s" % (r["night"], r["kind"], r["result"], r.get("words", ""), r["title"][:60]))
