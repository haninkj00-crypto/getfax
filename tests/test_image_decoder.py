import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except Exception:
    Image = None
    ImageDraw = None

ROOT = Path(__file__).resolve().parents[1]
PKG_CONFIG = shutil.which("pkg-config")
CC = shutil.which(os.environ.get("CC", "gcc"))
HAS_CODECS = bool(PKG_CONFIG and CC and Image is not None)
if HAS_CODECS:
    probe = subprocess.run(
        [PKG_CONFIG, "--exists", "libpng", "libjpeg", "libtiff-4"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    HAS_CODECS = probe.returncode == 0


@unittest.skipUnless(HAS_CODECS, "requires Pillow, GCC/Clang, pkg-config and libpng/libjpeg/libtiff")
class ImageDecoderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.work = Path(cls.temp.name)
        cls.generated = cls.work / "generated"
        subprocess.run([
            os.environ.get("PYTHON", "python3"), str(ROOT / "generator.py"),
            "--profile", str(ROOT / "profiles" / "gcc_c89.json"),
            "--outdir", str(cls.generated),
        ], check=True, capture_output=True, text=True)
        cflags = subprocess.check_output(
            [PKG_CONFIG, "--cflags", "libpng", "libjpeg", "libtiff-4"], text=True
        )
        libs = subprocess.check_output(
            [PKG_CONFIG, "--libs", "libpng", "libjpeg", "libtiff-4"], text=True
        )
        command = [CC, "-std=c89", "-pedantic", "-Wall", "-Wextra", "-Werror",
                   "-O2", "-DFAX_WITH_PNG", "-DFAX_WITH_JPEG", "-DFAX_WITH_TIFF"]
        command += shlex.split(cflags)
        command += [str(cls.generated / "fax_image.c"), str(ROOT / "tests" / "fax_image_dump.c"),
                    "-I" + str(cls.generated), "-o", str(cls.work / "fax_image_dump")]
        command += shlex.split(libs)
        subprocess.run(command, check=True, capture_output=True, text=True)
        cls.dump_exe = cls.work / "fax_image_dump"

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def decode(self, source, page=None):
        output = self.work / (source.stem + "_decoded.pgm")
        command = [str(self.dump_exe), str(source), str(output)]
        if page is not None:
            command.append(str(page))
        info = subprocess.run(command, check=True, capture_output=True, text=True).stdout.strip()
        return Image.open(output).convert("L"), info

    def test_png_alpha_is_composited_on_white_in_memory(self):
        source = self.work / "alpha.png"
        image = Image.new("RGBA", (20, 16), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle((3, 3, 15, 12), fill=(0, 0, 0, 128))
        image.save(source)
        decoded, _ = self.decode(source)
        self.assertEqual(decoded.size, (20, 16))
        self.assertEqual(decoded.getpixel((0, 0)), 255)
        self.assertIn(decoded.getpixel((3, 3)), (127, 128))

    def test_bmp_and_jpeg_metadata(self):
        source = self.work / "rgb.bmp"
        image = Image.new("RGB", (37, 23), (12, 80, 210))
        ImageDraw.Draw(image).rectangle((5, 4, 20, 18), fill=(0, 0, 0))
        image.save(source, dpi=(96, 96))
        decoded, bmp_info = self.decode(source)
        self.assertEqual(decoded.size, image.size)
        self.assertIn("BMP 37 23", bmp_info)

        jpeg = self.work / "rgb.jpg"
        image.save(jpeg, quality=90, dpi=(200, 196))
        decoded, jpeg_info = self.decode(jpeg)
        self.assertEqual(decoded.size, image.size)
        self.assertIn("JPEG 37 23 200.000 196.000", jpeg_info)

    def test_tiff_fax_compression_multipage_and_orientation(self):
        source = self.work / "fax.tif"
        bilevel = Image.new("1", (64, 32), 1)
        draw = ImageDraw.Draw(bilevel)
        draw.rectangle((7, 5, 29, 26), fill=0)
        bilevel.save(source, compression="group4", dpi=(204, 196))
        decoded, info = self.decode(source)
        self.assertEqual(decoded.size, bilevel.size)
        self.assertIn("TIFF 64 32 204.000 196.000", info)

        second = Image.new("L", (31, 17), 123)
        multi = self.work / "multi.tif"
        bilevel.convert("L").save(multi, save_all=True, append_images=[second], compression="tiff_lzw")
        decoded_second, info = self.decode(multi, page=1)
        self.assertEqual(decoded_second.size, second.size)
        self.assertEqual(decoded_second.getpixel((0, 0)), 123)
        self.assertIn("page=1", info)

        # Test all eight TIFF orientation transforms from known un-oriented
        # pixels. Pillow may apply the orientation tag when reopening a TIFF,
        # so expected output is built from the original byte sequence.
        width, height = 48, 32
        source_pixels = bytes((x * 3 + y * 7) % 256
                              for y in range(height) for x in range(width))
        for orientation in range(1, 9):
            oriented = self.work / ("orientation{}.tif".format(orientation))
            src = Image.frombytes("L", (width, height), source_pixels)
            src.save(oriented, compression="raw", tiffinfo={274: orientation}, dpi=(300, 200))
            decoded, oriented_info = self.decode(oriented)
            out_w, out_h = ((height, width) if orientation >= 5 else (width, height))
            expected = bytearray(out_w * out_h)
            for y in range(height):
                for x in range(width):
                    if orientation == 1:
                        dx, dy = x, y
                    elif orientation == 2:
                        dx, dy = width - 1 - x, y
                    elif orientation == 3:
                        dx, dy = width - 1 - x, height - 1 - y
                    elif orientation == 4:
                        dx, dy = x, height - 1 - y
                    elif orientation == 5:
                        dx, dy = y, x
                    elif orientation == 6:
                        dx, dy = height - 1 - y, x
                    elif orientation == 7:
                        dx, dy = height - 1 - y, width - 1 - x
                    else:
                        dx, dy = y, width - 1 - x
                    expected[dy * out_w + dx] = source_pixels[y * width + x]
            self.assertEqual(decoded.size, (out_w, out_h), orientation)
            self.assertEqual(decoded.tobytes(), bytes(expected), orientation)
            if orientation >= 5:
                self.assertIn("200.000 300.000", oriented_info)
            else:
                self.assertIn("300.000 200.000", oriented_info)


if __name__ == "__main__":
    unittest.main()
