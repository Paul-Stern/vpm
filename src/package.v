module main

import veb
import lib.log
import lib.storage
import lib.html
import markdown
import entity { Package }

@['/new']
fn (mut app App) new(mut ctx Context) veb.Result {
	app.title = 'Creating package | vpm'
	return $veb.html()
}

@['/create_package'; post]
pub fn (mut app App) create_package(mut ctx Context, name string, url string, description string) veb.Result {
	app.packages().create(name, url, description, app.cur_user) or {
		log.error()
			.add('error', err.str())
			.add('url', url)
			.add('name', name)
			.add('description', description)
			.add('user_id', app.cur_user.id)
			.msg('error creating package')

		ctx.error(err.msg())
		return app.new()
	}

	return ctx.redirect('/')
}

@['/users/:name']
pub fn (mut app App) user(mut ctx Context, name string) veb.Result {
	user := app.users().get_by_name(name) or {
		error_msg := 'Not found such user'
		return ctx.html($tmpl('./templates/error.html'))
	}

	app.title = user.username + ' packages | vpm'

	packages := app.packages().find_by_user(user.id)

	return $veb.html()
}

@['/packages']
pub fn (mut app App) packages_redir(mut ctx Context) veb.Result {
	return ctx.redirect('/search')
}

@['/packages/:name']
pub fn (mut app App) package(mut ctx Context, name string) veb.Result {
	pkg := app.packages().get(name) or {
		println(err)
		return ctx.redirect('/')
	}

	app.title = pkg.name + ' | vpm'

	categories := app.packages().get_package_categories(pkg.id) or { [] }

	// Getting README from repo or storage
	readme_path := '/packages_readme/${pkg.id}/README.html'
	data := app.get_readme(mut ctx, pkg.name, readme_path) or {
		println(err)
		''
	}

	pkg_readme := data

	return ctx.html($tmpl('./templates/package.html'))
}

fn (mut app App) get_readme(mut ctx Context, name string, readme_path string) !string {
	data := app.storage.read(readme_path) or {
		if err != storage.err_not_found {
			return error('failed to read readme from storage: ${err}')
		}

		println('fetching readme from repo for `${name}`')

		// TODO: figure out when to update readme
		readme := app.packages().get_package_markdown(name) or {
			return error('failed to get readme from repo: ${err}')
		}

		rendered := html.sanitize(markdown.to_html(readme)).bytes()

		app.storage.save(readme_path, rendered) or {
			println('failed to save readme to storage: ${err}')
		}

		rendered
	}
	return data.bytestr()
}

@['/packages/:name/edit']
pub fn (mut app App) edit(mut ctx Context, name string) veb.Result {
	pkg := app.packages().get(name) or {
		ctx.error(err.msg())
		return app.edit(mut ctx, name)
	}

	app.title = 'Editing «${pkg.name}» | vpm'
	if !app.is_able_to_edit(pkg) {
		return ctx.redirect('/packages/${name}')
	}

	pkg_name := pkg.name.split('.')[1] or { pkg.name }

	return $veb.html()
}

@['/packages/:name/edit'; POST]
pub fn (mut app App) perform_edit(mut ctx Context, name string) veb.Result {
	pkg := app.packages().get(name) or {
		ctx.error(err.msg())
		return app.edit(mut ctx, name)
	}

	if !app.is_able_to_edit(pkg) {
		return ctx.redirect('/packages/${name}')
	}

	mut pkg_name := ctx.form['name'] or {
		ctx.error('package name not been provided')
		return app.edit(mut ctx, name)
	}

	url := ctx.form['url'] or { pkg.url }
	description := ctx.form['description'] or { pkg.description }
	app.packages().update_package_info(pkg.id, pkg_name, url, description) or {
		ctx.error(err.msg())
		return app.edit(mut ctx, name)
	}

	return ctx.redirect('/')
}

@['/packages/:name/delete']
pub fn (mut app App) delete(mut ctx Context, name string) veb.Result {
	pkg := app.packages().get(name) or {
		ctx.error(err.msg())
		return app.delete(mut ctx, name)
	}

	app.title = 'Deleting «${pkg.name}» | vpm'

	if !app.is_able_to_edit(pkg) {
		return ctx.redirect('/packages/${name}')
	}

	return $veb.html()
}

@['/packages/:name/delete'; POST]
pub fn (mut app App) perform_delete(mut ctx Context, name string) veb.Result {
	pkg := app.packages().get(name) or {
		ctx.error(err.msg())
		return app.delete(mut ctx, name)
	}

	if !app.is_able_to_edit(pkg) {
		return ctx.redirect('/packages/${name}')
	}

	pkg_name := ctx.form['name'] or { '' }

	if pkg_name != pkg.name {
		ctx.error('name is not matching')
		return app.delete(mut ctx, name)
	}

	user_id := if app.cur_user.is_admin { pkg.user_id } else { app.cur_user.id }
	app.packages().delete(pkg.id, user_id) or {
		ctx.error(err.msg())
		return app.delete(mut ctx, name)
	}

	return ctx.redirect('/')
}

fn (mut app App) is_able_to_edit(pkg Package) bool {
	return app.cur_user.is_admin || app.cur_user.id == pkg.user_id
}
