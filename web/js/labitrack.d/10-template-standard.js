λ.templates.register('standard', function(){

	var qrcode = null;
	var qrcode_url = null;
	var left=1;
	var right=2;

	function drawCircle(ctx) {
		ctx.beginPath();
		ctx.arc(40, 0, 40, 0, Math.PI*2);
		ctx.lineWidth = 8;
		ctx.stroke();
		ctx.closePath();
	}

	function roundedRect(ctx, x, y, w, h, r) {
		ctx.save();
		ctx.translate(x, y);
		ctx.moveTo(0, r);
		ctx.arc(r, r, r, Math.PI, Math.PI*1.5);
		ctx.lineTo(w-r, 0);
		ctx.arc(w-r, r, r, Math.PI*1.5, Math.PI*2);
		ctx.lineTo(w, h-r);
		ctx.arc(w-r, h-r, r, 0, Math.PI*0.5);
		ctx.lineTo(r, h);
		ctx.arc(r, h-r, r, Math.PI*0.5, Math.PI);
		ctx.lineTo(0, r);
		ctx.restore();
	}

	function measureCircle(ctx) {
		return {width: 82, align: left};
	}

	function drawPerson(ctx, x, y) {
		var m = this.measure(ctx);
		ctx.save();
		ctx.translate(x, y);

		drawCircle(ctx);

		ctx.beginPath();
		ctx.arc(40, -25, 7.5, 0, Math.PI*2);
		ctx.rect(32, -15, 16, 3);
		ctx.moveTo(32, -12);
		ctx.arc(32, -12, 2.5, Math.PI*1, Math.PI*1.5);
		ctx.moveTo(48, -12);
		ctx.arc(48, -12, 2.5, Math.PI*1.5, Math.PI*2);
		ctx.rect(28, -12, 24, 20);
		ctx.rect(32, 8, 16, 20);
		ctx.fill();
		ctx.closePath();

		ctx.restore();

		return m.width;
	}

	var stamplinewidth = 8;

	function drawManual(ctx, x, y) {
		var m = this.measure(ctx);
		ctx.save();
		ctx.translate(x, y);

		drawCircle(ctx);

		ctx.beginPath();
		ctx.moveTo(6, -25);
		roundedRect(ctx, 20, -25, 30, 40, 5);
		roundedRect(ctx, 30, -15, 30, 40, 5);
		ctx.lineWidth = 4;
		ctx.stroke();
		ctx.closePath();

		ctx.restore();

		return m.width;
	}


	function measureStamp(ctx, label)
	{
		ctx.font = '60px sans-serif';
		var tm = ctx.measureText(label);
		return {width: tm.width + 40 + 8, align: right};
	}

	function drawStamp(ctx, label, x, y)
	{
		ctx.save();
		ctx.translate(x, y);

		ctx.font = '60px sans-serif';
		var tm = ctx.measureText(label);

		ctx.beginPath();
		var m = this.measure(ctx, label);
		ctx.rect(stamplinewidth/2, -40, m.width - stamplinewidth, 80+(stamplinewidth/2), Math.PI*2);
		ctx.lineWidth = stamplinewidth;
		ctx.stroke();
		ctx.closePath();

		ctx.fillText(label, (m.width - stamplinewidth - tm.width)/2, 20);

		ctx.restore();
		return m.width;
	}

	var symbols = function(){
		var symbols = {};

		function register(key, draw, measure) {
			symbols[key] = {draw: draw, measure: measure};
		}
		function get() {
			return symbols;
		}
		return {get: get, register: register};
	}();

	function registerStamp(key, label) {
		symbols.register(key,
			function(ctx, x, y){
				return drawStamp.apply(this, [ctx, label, x, y]);
			},
			function(ctx){
				return measureStamp(ctx, label);
			});
	}

	registerStamp('dnh', 'DNH');
	registerStamp('dohack', 'DO HACK');
	registerStamp('dne', 'DNE');
	symbols.register('person', drawPerson, measureCircle);
	symbols.register('manual', drawManual, measureCircle);

	function drawQRcode(ctx, size, url) {
		if (qrcode_url !== url) {
			qrcode = null;
			qrcode_url = url;
		}
		if (qrcode === null) {
			// calculate the qrcode
			qrcode = new QRCode(-1, QRErrorCorrectLevel.L);
			qrcode.addData(url);
			qrcode.make();
		}

		ctx.save();
		var scale = size / (qrcode.getModuleCount()+2);
		ctx.scale(scale, scale);

		// draw on the canvas
		ctx.beginPath();
		for (var row = 0; row < qrcode.getModuleCount(); row++){
			for (var col=0; col < qrcode.getModuleCount(); col++){
				if (qrcode.isDark(row, col)) {
					ctx.rect(col+1, row+1, 1, 1);
				}
			}
		}
		ctx.closePath();
		ctx.fill();
		ctx.restore();
	}

	function draw(data, preview)
	{
		var dw;
		if (preview) {
			dw = 560;
		} else {
			dw = 1083;
		}
		var w = 1083;
		var ds = dw/w;
		var h = 336;
		var dh = Math.round(h * ds);
		var ctx = labitrack.utils.new_context(dw, dh);
		ctx.scale(ds, ds)

		ctx.shadowBlur = 0;
		ctx.globalAlpha = 1;


		drawQRcode(ctx, h, 'http://o.sudoroom.org/'+data.id);

// ToDo make it use name instead of id (but also fix it in templates/labitrack.d/view)
//		drawQRcode(ctx, h, 'http://o.sudoroom.org/'+encodeURIComponent(data.name));

		ctx.translate(h, 0);
		var y = 50;
		ctx.font = 'bold 40px sans-serif';
		ctx.fillText(data.name, 20, y);
		y += 45;
		ctx.font = '40px sans-serif';
		ctx.fillText('ID: '+data.id, 20, y);
		y += 40;
		ctx.font = 'italic 40px sans-serif';
		var lines = data.desc.split('\n');
		for (var i=0; i<lines.length;i++) {
			ctx.fillText(lines[i], 20, y);
			y += 40;
		}

		function drawline(y, x, w) {
			ctx.save();
			ctx.beginPath();
			ctx.moveTo(x, y);
			ctx.lineTo(x+w, y);
			ctx.strokeStyle = 'red 1px';
			ctx.stroke();
			ctx.closePath();
			ctx.restore();
		}

		function drawSymbols(ctx) {
			var l = 20;
			var r = 750;
			var y = 280;
			var p = 15;

			var tags = data.tags;
			var syms = symbols.get();
			for (tag in syms) {
				var found = false;
				for (var i=0; i<tags.length; i++) {
					if (tag === tags[i]) {
						found = true;
						break;
					}
				}
				if (!found) continue;

				var sym = syms[tag];

				var m = sym.measure(ctx);
				if (m.align === left) {
					//drawline(y-50-(i*10), l, m.width);
					l += sym.draw(ctx, l, y) + p;
				} else {
					r -= m.width + p;
					//drawline(y-50-(i*10), r, m.width);
					sym.draw(ctx, r, y);
				}
			}
		}

		drawSymbols(ctx);

		return ctx.getImageData(0, 0, dw, dh);
	}

	return {'draw': draw};

}());
