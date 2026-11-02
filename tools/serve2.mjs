// tiny static server for Studio's upload_image (serves one folder on localhost only); stop it right after the upload
import http from "node:http"; import fs from "node:fs"; import path from "node:path";
const root = process.argv[2], port = Number(process.argv[3] || 8766);
http.createServer((req, res) => {
  const f = path.join(root, decodeURIComponent(req.url.split("?")[0]).replace(/^\/+/, ""));
  if (!f.startsWith(root) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "Content-Type": f.endsWith(".png") ? "image/png" : "text/plain" }); fs.createReadStream(f).pipe(res);
}).listen(port, "127.0.0.1", () => console.log("SERVING", root, port));
