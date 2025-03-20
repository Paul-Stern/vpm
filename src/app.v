module main

import veb
import config
import entity { Category, Package, User }
import db.pg
import usecase.package
import lib.storage
import usecase.user
import net.urllib
import repo
import time

struct App {
	config config.Config
pub mut:
	db       pg.DB
	title    string
	cur_user User
	storage  storage.Provider

	nr_packages               &string = unsafe { nil }
	categories                []Category
	new_packages              []Package
	recently_updated_packages []Package
	most_downloaded_packages  []Package
	last_update               &time.Time = unsafe { nil }
}

pub struct Context {
	veb.Context
}

// Whole app middleware
pub fn (mut app App) before_request(mut ctx Context) {
	url := urllib.parse(ctx.req.url) or { panic(err) }

	// Skip auth for static
	if url.path == '/favicon.png' || url.path.starts_with('/css') || url.path.starts_with('/js') {
		// Set cache for a week
		ctx.set_header(.cache_control, 'max-age=604800')
		return
	}

	app.auth(mut ctx)
}

fn (mut app App) packages() package.UseCase {
	return package.UseCase{
		categories: repo.categories(app.db)
		packages:   repo.packages(app.db)
		users:      repo.users(app.db)
	}
}

fn (mut app App) users() user.UseCase {
	return user.UseCase{
		users: repo.users(app.db)
	}
}

fn (mut app App) is_logged_in() bool {
	return app.cur_user.username != ''
}

// used by templates
fn less_than(i int, value int) bool {
	return i < value
}
