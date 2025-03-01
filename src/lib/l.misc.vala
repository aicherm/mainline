// 

namespace l.misc {

	public int VERBOSE = 1;

	private static void set_locale() {
		Intl.setlocale(LocaleCategory.MESSAGES,BRANDING_SHORTNAME);
		Intl.textdomain(BRANDING_SHORTNAME);
		Intl.bind_textdomain_codeset(BRANDING_SHORTNAME,"utf-8");
		Intl.bindtextdomain(BRANDING_SHORTNAME,LOCALE_DIR);
	}

	public void vprint(string s,int v=1,FileStream f=stdout,bool n=true) {
		if (v>VERBOSE) return;
		string o = s;
		if (VERBOSE>3) o = "%d: ".printf(Posix.getpid()) + o;
		if (n) o += "\n";
		f.printf(o);
		f.flush();
	}

	public void uri_open(string s) {
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { warning("Unable to launch %s",s); }
	}

	private static void pbar(int64 part=0,int64 whole=100,string units="") {
		if (VERBOSE<1) return;
		if (whole==0) { vprint("\r%79s\r".printf(""),1,stdout,false); return; }

		int64 c = 0, plen = 0, wlen = 40;
		string b = "", u = units;

		if (whole>0) { c=(part*100/whole); plen=(part*wlen/whole); }
		else { c=100; plen=wlen; }

		for (int i=0;i<wlen;i++) { if (i<plen) b+="▓"; else b+="░"; }
		if (u.length>0) u = " "+part.to_string()+"/"+whole.to_string()+" "+u;
		vprint("\r%79s\r%s %d%% %s ".printf("",b,(int)c,u),1,stdout,false);
	}

	public bool try_ppa() {
		vprint("try_ppa()",4);
		if (App.ppa_tried) return App.ppa_up;

		string std_err, std_out;
		string cmd = "aria2c"
		+ " --no-netrc"
		+ " --no-conf"
		+ " --max-file-not-found=3"
		+ " --retry-wait=2"
		+ " --max-tries=3"
		+ " --dry-run"
		+ " --quiet";

		if (App.connect_timeout_seconds>0) cmd += " --connect-timeout="+App.connect_timeout_seconds.to_string();

		if (App.all_proxy.length>0) cmd += " --all-proxy='"+App.all_proxy+"'";

		cmd += " '"+App.ppa_uri+"'";

		vprint(cmd,3);

		int status = exec_sync(cmd, out std_out, out std_err);
		if (std_err.length > 0) vprint(std_err,1,stderr);

		App.ppa_tried = true;
		App.ppa_up = false;
		if (status == 0) App.ppa_up = true;
		else vprint(_("Can not reach site")+": \""+App.ppa_uri+"\"",1,stderr);

		App.ppa_up = true;
		return App.ppa_up;
	}

	// execute command synchronously
	public int exec_sync(string cmd, out string? std_out = null, out string? std_err = null) {
		try {
			int status;
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out status);
			return status;
		} catch (SpawnError e) {
			vprint(e.message,1,stderr);
			return -1;
	    }
	}

	// 20200510 bkw - execute command without waiting
	public void exec_async(string cmd) {
		try { Process.spawn_command_line_async (cmd); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
	}

	public GLib.Timer timer_start() {
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public ulong timer_elapsed(GLib.Timer timer, bool stop = true) {
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop) timer.stop();

		return (ulong)((seconds * 1000 ) + (microseconds / 1000));
	}

	public void sleep(int milliseconds) {
		Thread.usleep ((ulong) milliseconds * 1000);
	}

}
