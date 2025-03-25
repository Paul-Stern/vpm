module main

import veb

@['/search']
pub fn (mut app App) search(mut ctx Context) veb.Result {
	query := ctx.query['q']
	category := ctx.query['category']
	sort := ctx.query['sort']

	title := if query == '' { 'All Packages' } else { 'Search Results' }
	app.title = title + ' | vpm'

	mut packages := app.packages().query(query, sort) // NOTE: packages variable is used in search.html template
	if category.len > 0 {
		if cpkgs := app.packages().get_category_packages(category) {
			ids := cpkgs.map(it.id)
			packages = packages.filter(it.id in ids)
		}
	}

	return $veb.html()
}
