"""Illustrative example cards for the marketing library. They reuse the website card classes (Website/site.css)
and show only live V1 behaviour: Grub Rank, Signature Dishes, every cook of a Dish, Food Bible (Paste Recipe /
Add Manually), Send a Recipe to Sous Chefs, Rank My Version with creator credit, The Pass with Hands and Comments,
Tickets and Tag a Sous Chef. Every card is rendered with an "Illustrative preview" caption; names, dishes and
scores are examples, never real users or activity. No follower model, Stars, Want to Cook or Run It Back.
"""
import html


def esc(text):
    return html.escape(text, quote=True)


def avatar(name):
    return f'<span class="avatar" aria-hidden="true">{esc(name[0])}</span>'


def card(label, body, extra=""):
    return f'<div class="card example {extra}" role="img" aria-label="Illustrative example: {esc(label)}">{body}</div>'


def signature():
    rows = [("Rack of Lamb", "9.4"), ("Mushroom Risotto", "8.8"), ("Pan-Seared Duck Breast", "8.1")]
    items = "".join(f'<li><span class="medal">{i}</span><span class="rank-name">{esc(n)}<small>Signature Dish</small></span>'
                    f'<span class="score">{s}</span></li>' for i, (n, s) in enumerate(rows, 1))
    return card("Signature Dishes", f'<p class="card-head">Signature Dishes</p><ol class="rank-list signature">{items}</ol>')


def progress():
    cooks = [("First loaf", "Sep 6", 6.2), ("Longer proof", "Sep 20", 7.4), ("Higher hydration", "Oct 4", 8.3),
             ("Cold overnight proof", "Oct 18", 9.1)]
    rows = "".join(f'<li><span class="cook-name">{esc(n)}<time>{d}</time></span>'
                   f'<span class="bar"><i style="width:{s * 10:.0f}%"></i></span><span class="score">{s}</span></li>'
                   for n, d, s in cooks)
    return card("four cooks of a Sourdough Loaf improving from 6.2 to 9.1",
                '<p class="eyebrow">Dish</p><p class="card-title">Sourdough Loaf</p><p class="muted">4 cooks</p>'
                f'<ul class="progress-list">{rows}</ul>')


def add_recipe():
    return card("adding a Recipe to Food Bible",
                '<p class="eyebrow">Food Bible</p><p class="card-title">Add a Recipe</p>'
                '<div class="picks"><p class="pick chosen"><span>Paste Recipe<small>Paste text from anywhere. Review, then Save.</small></span>'
                '<span class="check" aria-hidden="true">✓</span></p>'
                '<p class="pick"><span>Add Manually<small>Write it your way.</small></span></p></div>', "versus")


def send_recipe():
    chefs = [("Sam", True), ("Priya", True), ("Jordan", False)]
    rows = "".join(f'<li>{avatar(n)}<span>{n}</span>' + ('<span class="check" aria-hidden="true">✓</span>' if on else
                                                        '<span class="ring" aria-hidden="true"></span>') + '</li>'
                   for n, on in chefs)
    return card("sending a Recipe to two Sous Chefs",
                '<p class="eyebrow">Food Bible</p><p class="card-title">Brown Butter Gnocchi</p><p class="muted">Serves 2 · 40 min</p>'
                f'<p class="section-label">Send to Sous Chefs</p><ul class="people">{rows}</ul>'
                '<p class="action-button">Send</p>')


def rank_my_version():
    return card("making a Sous Chef's Recipe and ranking your version",
                f'<p class="byline">{avatar("Alex")}Recipe by Alex</p><p class="card-title">Shakshuka</p>'
                '<p class="muted">Serves 2 · 30 min</p><p class="action-button">Rank My Version</p>'
                '<p class="section-label">Your cook</p>'
                '<p class="my-cook"><span>Extra-Spicy Shakshuka<small>Recipe by Alex</small></span><span class="score">8.6</span></p>')


def pass_post():
    return card("a cook posted to The Pass with Hands and Comments",
                f'<p class="byline">{avatar("Sam")}Sam<time>2h</time></p>'
                '<p class="card-title">Brown Butter Gnocchi<span class="pill">9.1</span></p>'
                '<p>Crispy edges this time. Finally.</p>'
                '<p class="actions"><span>🙌 12</span><span>💬 3</span><span class="recipe-link">Recipe</span></p>')


def comments():
    rows = [("Priya", "Recipe please! 🙏"), ("Jordan", "Making this on Sunday."), ("Sam", "Sent it to you 🧑‍🍳")]
    items = "".join(f'<li>{avatar(n)}<span><b>{n}</b> {esc(t)}</span></li>' for n, t in rows)
    return card("comments on a cook in The Pass",
                '<p class="card-head">Comments</p>'
                f'<ul class="comment-list">{items}</ul><p class="comment-field">Add a comment…</p>')


def tickets():
    rows = [("Sam", "gave Hands 🙌 to your Herb-Crusted Rack of Lamb"), ("Priya", "commented on your Shakshuka"),
            ("Jordan", "sent you a Recipe: Brown Butter Gnocchi"), ("Alex", "accepted your Sous Chef request")]
    items = "".join(f'<li>{avatar(n)}<span><b>{n}</b> {esc(t)}</span></li>' for n, t in rows)
    return card("Tickets from Sous Chefs", f'<p class="card-head">Tickets 🎟️</p><ul class="comment-list tickets">{items}</ul>')


def tag_chef():
    return card("tagging a Sous Chef on a cook",
                '<p class="eyebrow">Cook</p><p class="card-title">Homemade Ramen</p><p class="muted">Cooked together</p>'
                f'<p class="section-label">Tag a Sous Chef 🧑‍🍳</p><p class="chips"><span class="chip on">{avatar("Sam")}Sam ✓</span>'
                f'<span class="chip">{avatar("Priya")}Priya</span></p>')
