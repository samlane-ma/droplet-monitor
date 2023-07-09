/*
 * This file is part of the vala-curl project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * This file has been included as part of the Budgie Droplet Monitor
 * Applet. It has been modified to work more seamlessly with the applet.
 * The original files are found at <https://github.com/Richard-W/curl-vala>
 */

using Native.Curl;

[CCode(lower_case_cprefix="vcurl_",cprefix="VCURL_")]
namespace Curl {

	public errordomain CurlError {
		PERFORM_FAILED
	}

	public void global_init() {
		Native.Curl.Global.init((long) Native.Curl.GLOBAL_ALL);
	}

	public void global_cleanup() {
		Native.Curl.Global.cleanup();
	}

	public class CurlInputStream : MemoryInputStream {
	}

	public class CurlOutputStream : GLib.OutputStream {
		private CurlInputStream input_stream;

		public CurlOutputStream(CurlInputStream input_stream) {
			this.input_stream = input_stream;
		}

		public override ssize_t write(uint8[] buffer, Cancellable? cancellable = null) throws GLib.IOError {
			input_stream.add_data(buffer, GLib.free);
			return (ssize_t)buffer.length;
		}

		public override bool close(Cancellable? cancellable = null) throws GLib.IOError {
			return input_stream.close();
		}
	}

	private size_t read_function(void* ptr, size_t size, size_t nmemb, void* data) {
		size_t bytes = size * nmemb;
		InputStream stream = (InputStream) data;

		uint8[] buffer = new uint8[bytes];
		size_t read_bytes;
		try {
			read_bytes = stream.read(buffer, null);
		} catch(GLib.IOError e) {
			stderr.printf("IOError in read_function: %s\n",e.message);
			return 0;
		}
		
		Posix.memcpy(ptr, (void*)buffer, read_bytes);

		return read_bytes;
	}

	private size_t write_function(void* buf, size_t size, size_t nmemb, void *data) {
		size_t bytes = size * nmemb;
		OutputStream stream = (OutputStream) data;

		uint8[] buffer = new uint8[bytes];
		Posix.memcpy((void*)buffer, buf, bytes);

		size_t bytes_written;
		try {
			bytes_written = stream.write(buffer, null);
		} catch(GLib.IOError e) {
			stderr.printf("IOError in write_function: %s\n", e.message);
			return 0;
		}

		return bytes_written;
	}

	public class Easy : Object {
		private EasyHandle handle;

		/* References to be sure the objects do not get freed prematurely */
		private OutputStream output_stream;
		private InputStream input_stream;
		private Native.Curl.SList header;

		public Easy() {
			this.handle = new EasyHandle();
		}

		/** Perform the transfer after options are set */
		public void perform() throws CurlError {
			Code res = this.handle.perform();
			if(res != Code.OK)
				throw new CurlError.PERFORM_FAILED(Global.strerror(res));
		}

		/** Get a CurlOutputStream you can write data to send to */
		public CurlOutputStream get_output_stream() {
			var input_stream = new CurlInputStream();
			var output_stream = new CurlOutputStream(input_stream);
			this.set_input_stream(input_stream);
			return output_stream;
		}

		/** Get a CurlInputStream you can read received data from */
		public CurlInputStream get_input_stream() {
			var input_stream = new CurlInputStream();
			var output_stream = new CurlOutputStream(input_stream);
			this.set_output_stream(output_stream);
			return input_stream;
		}

		/** This sets the output-stream that curl will write to */
		public void set_output_stream(OutputStream output_stream) {
			this.output_stream = output_stream;
			this.handle.setopt(Option.WRITEFUNCTION, write_function);
			this.handle.setopt(Option.FILE, (void*)output_stream);
		}

		/** This sets the input-stream that curl will read from */
		public void set_input_stream(InputStream input_stream) {
			this.input_stream = input_stream;
			this.handle.setopt(Option.READFUNCTION, read_function);
			this.handle.setopt(Option.INFILE, (void*)input_stream);
		}

		public void set_url(string url) {
			this.handle.setopt(Option.URL, url);
		}

		public void set_header(string[] headers) {
			header = null;
			foreach (string element in headers) {
			    header = Native.Curl.SList.append((owned)header, element);
			}
			this.handle.setopt(Option.HTTPHEADER, header);
		}

		public void set_post(string postdata) {
			this.handle.setopt(Option.CUSTOMREQUEST, "POST");
			this.handle.setopt(Option.POSTFIELDS, postdata);
			this.handle.setopt(Option.POSTFIELDSIZE, (long) postdata.length);
		}
	}


}
