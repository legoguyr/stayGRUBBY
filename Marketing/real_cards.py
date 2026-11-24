"""Cards built only from @grubwithguy's read-only data snapshot (real-cooking/data.json): real Dish names, cook
names, displayed scores, ranks, Recipes and Hands/comment counts. Nothing here is invented; if a value is not in the
snapshot it is not shown. Each figure is captioned "Real data · @grubwithguy · as of <date>" by the renderer.
"""
import html
import json
from pathlib import Path

DATA = json.loads((Path(__file__).resolve().parent / "real-cooking/data.json").read_text())
TOP = {row["rank"]: row for row in DATA["top20"]}


def esc(text):
    return html.escape(str(text), quote=True)


def label(row):
    return row["dish"] + (f' · {row["cook"]}' if row.get("cook") else "")


def caption():
    return f'Real data · {DATA["handle"]} · as of {DATA["as_of"]}'


def photo_label(slot):
    for row in DATA["top20"]:
        if row["photo"] == slot:
            return f'#{row["rank"]} {label(row)}'
    return slot


def card(aria, body, extra=""):
    return f'<div class="card real {extra}" role="img" aria-label="{esc(aria)}">{body}</div>'


def top(arg="1-5"):
    first, last = (int(x) for x in arg.split("-"))
    rows = [TOP[r] for r in range(first, last + 1)]
    items = "".join(
        f'<li><span class="rank-no">{r["rank"]}</span><span class="rank-name">{esc(r["dish"])}'
        + (f'<small class="cook">{esc(r["cook"])}</small>' if r.get("cook") else "")
        + ('<small>Signature Dish</small>' if r["rank"] <= 3 else "")
        + f'</span><span class="score">{r["score"]}</span></li>' for r in rows)
    head = "Signature Dishes" if (first, last) == (1, 3) else f"Grub Rank · Top {last}" if first == 1 else f"Grub Rank · {first}–{last}"
    return card(f"{DATA['handle']} Grub Rank {first} to {last}", f'<p class="card-head">{head}</p><ol class="rank-list compact">{items}</ol>')


def two_cooks(_=""):
    t = DATA["two_cooks"]
    rows = "".join(f'<li><span class="cook-name">{esc(c["cook"])}<time>Cook {c["order"]} · #{c["rank"]} of {DATA["ranked_cooks"]}</time></span>'
                   f'<span class="score">{c["score"]}</span></li>' for c in t["cooks"])
    return card("Two cooks of Lamb Chops ranked separately",
                f'<p class="eyebrow">Dish</p><p class="card-title">{esc(t["dish"])}</p><p class="muted">{len(t["cooks"])} cooks, each ranked</p>'
                f'<ul class="progress-list two">{rows}</ul>')


def recipe(name):
    r = DATA["recipes"][name]
    meta = " · ".join(x for x in (r.get("yield"), r.get("time"), r.get("cuisine")) if x)
    items = "".join(f"<li><span>{esc(i)}</span></li>" for i in r["ingredients"])
    more = r["ingredients_total"] - len(r["ingredients"])
    footer = f'{r["ingredients_total"]} ingredients · {r["steps"]} steps'
    ranked = f'<p class="ranked-chip">Grub Rank #{r["dish_rank"]}</p>' if r.get("dish_rank") else ""
    return card(f"Food Bible Recipe {name}",
                f'<p class="eyebrow">Food Bible</p><p class="card-title">{esc(name)}</p><p class="muted">{esc(meta)}</p>'
                f'<ul class="cook-list">{items}</ul><p class="muted small">{"+ " + str(more) + " more · " if more > 0 else ""}{footer}</p>{ranked}')


def share_recipe(name):
    r = DATA["recipes"][name]
    return card(f"Rank My Version on {DATA['handle']}'s {name}",
                f'<p class="byline"><span class="avatar" aria-hidden="true">G</span>Recipe by {esc(DATA["handle"])}</p>'
                f'<p class="card-title">{esc(name)}</p><p class="muted">{esc(" · ".join(x for x in (r.get("yield"), r.get("time")) if x))}</p>'
                '<p class="action-button">Rank My Version</p><p class="muted small center">Cook it. Rank your version. The Recipe stays credited to its creator.</p>')


def post(name):
    p = next(x for x in DATA["posts"] if x["dish"] == name)
    recipe_link = '<span class="recipe-link">Recipe</span>' if p.get("recipe") else ""
    comments = f'<span>💬 {p["comments"]}</span>' if p["comments"] else ""
    return card(f"{name} posted to The Pass with {p['hands']} Hands",
                f'<p class="byline"><span class="avatar" aria-hidden="true">G</span>{esc(DATA["handle"])}</p>'
                f'<p class="card-title">{esc(name)}<span class="pill">{p["score_at_sharing"]}</span></p>'
                f'<p class="actions"><span>🙌 {p["hands"]}</span>{comments}{recipe_link}</p>')


def moved(_=""):
    m = DATA["moved"]
    return card(f"{m['dish']} moved from #{m['shared_rank']} to #{m['rank']}",
                f'<p class="eyebrow">Grub Rank</p><p class="card-title">{esc(m["dish"])}</p>'
                f'<div class="moved"><p><small>Shared {m["shared_day"]}</small><b>#{m["shared_rank"]}</b><span>{m["shared_score"]}</span></p>'
                f'<p class="arrow" aria-hidden="true">→</p><p class="now"><small>Today</small><b>#{m["rank"]}</b><span>{m["score"]}</span></p></div>'
                f'<p class="muted small">Of {m["shared_of"]} ranked cooks. More cooks, more comparisons, sharper ranks.</p>')


def paste_flow(name="Pasta alla Norma"):
    steps = [("Paste Recipe", "Paste the text you already have"), ("Review", "AI drafts it. You check and edit."),
             ("Save", "It's in your Food Bible")]
    rows = "".join(f'<li><span class="medal">{n}</span><span><b>{t}</b><small>{s}</small></span></li>' for n, (t, s) in enumerate(steps, 1))
    return card("Add a Recipe: Paste Recipe, review, save", f'<p class="card-head">Add a Recipe</p><ol class="flow">{rows}</ol>', "flow-card")


CARDS = {"real-top": top, "real-two-cooks": two_cooks, "real-recipe": recipe, "real-share-recipe": share_recipe,
         "real-post": post, "real-moved": moved, "real-paste-flow": paste_flow}
