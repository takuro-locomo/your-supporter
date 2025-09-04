import express from 'express';
import { Storage } from '@google-cloud/storage';
import { execFile } from 'child_process';
import { promisify } from 'util';

const exec = promisify(execFile);
const app = express();
app.use(express.json({ limit: '1mb' }));

const storage = new Storage();

async function downloadTemp(bucketName, srcPath, dstPath) {
  await storage.bucket(bucketName).file(srcPath).download({ destination: dstPath });
}
async function uploadFile(bucketName, srcPath, dstPath, contentType = 'video/mp4') {
  await storage.bucket(bucketName).upload(srcPath, { destination: dstPath, metadata: { contentType } });
}

app.post('/transcode', async (req, res) => {
  try {
    const { bucket, src, dest } = req.body || {};
    if (!bucket || !src || !dest) return res.status(400).json({ error: 'bucket/src/dest required' });

    const inFile = '/tmp/in.mp4';
    const outFile = '/tmp/out.mp4';
    await downloadTemp(bucket, src, inFile);

    // 720p/30fps/H.264 + AAC（平均2.5Mbps）
    await exec('ffmpeg', ['-y', '-i', inFile, '-vf', 'scale=-2:720', '-r', '30', '-c:v', 'libx264', '-preset', 'veryfast', '-b:v', '2500k', '-c:a', 'aac', '-b:a', '128k', outFile]);

    await uploadFile(bucket, outFile, dest, 'video/mp4');
    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: String(e) });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log('transcoder listening on', port));


