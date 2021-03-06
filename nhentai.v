import os
import time
import x.json2
import net.http


struct Doujin {
	cdn_url string = 'https://i.nhentai.net/galleries'
	mut:
		id string
		media_id string
		title map[string]json2.Any
		pages json2.Any
}

pub fn (mut d Doujin) from_json(f json2.Any) {
	obj := f.as_map()
	for key, value in obj {
		match key {
			'id' { d.id = value.str() }
			'media_id' { d.media_id = value.str() }
			'title' { d.title = value.as_map() }
			'images' { d.pages = value.as_map()['pages'] }	
			else {}
		}
	}
}


fn download_loop(url string, path string, i int) {
	time.sleep((i*100) * time.millisecond)
	http.download_file(url, path) or {
		println('> Page #$i download failed: restarting...')
		download_loop(url, path, i)
	}
}

fn (d Doujin) download_doujin() {
	mut threads := []thread{}

	// Check if doujin folder exists
	if !os.exists('downloads/${d.id}/') {
		os.mkdir('downloads/${d.id}/') or {
			println('Failed to create doujin folder: $err')
		}
	}

	for i, page_ in d.pages.arr() {
		page := page_.as_map()
		format := match page['t'].str() {
			'j' { 'jpg' }
			'p' { 'png' }
			'g' { 'gif'}
			else {'jpg'}
		}

		threads << go download_loop	(
			'$d.cdn_url/$d.media_id/${i+1}.$format',
			'downloads/$d.id/${i+1}.$format',
			i
			)
	}

	for i, task in threads {
		println('Starting page #${i+1}')
		task.wait()
		println('Finished page #${i+1}')
	}

}

[heap]
struct NHentai {
	api_url string = 'https://nhentai.net/api/gallery'
}

fn (d NHentai) from_code(code string) ?Doujin {
	println('> Doujin code: ${code}')

	resp_raw := http.get('${d.api_url}/${code}') or {
		println('Request failed: $err')
		return err
	}

	if resp_raw.status_code != 200 {
		return error('Status code is not 200')
	}

	resp := json2.decode<Doujin>(resp_raw.text) or {
		println('Failed to decode json!: $err')
		return err
	}

	println('Doujin id: $resp.id')
	println('Doujin name: ${resp.title["pretty"]} | ${resp.pages.as_map().len} pages')

	return resp
}


fn main() {
	args := os.args.clone()

	if args.len < 2 {
		println('nHentai shit downloader')
		println('error: wheres the code retard \n')
		println('args:')
		println('* code: int - the fucking code for nhentai')
		return
	}	

	// Check download folder
	if !os.exists('downloads') {
		os.mkdir('downloads') or {
			println('Failed to create download folder!: $err') 
			// should never happen unless
			// some bullshit perms is fucking up the program
		}
	}

	code := args[1]
	doujin := NHentai{}.from_code(code) or {
		println('Failed to get Doujin: $err')
		return
	}

	sw := time.new_stopwatch()
	// Download; very broken atm lol
	doujin.download_doujin()
	println('Downloading took: ${sw.elapsed().seconds()}s')
	
}
