#include <stdio.h>
#include <stdlib.h>
#include "fax_image.h"

int main(int argc, char **argv)
{
    fax_image image;
    char error_text[256];
    FILE *output;
    unsigned long page;
    size_t count;
    if (argc < 3) {
        fprintf(stderr, "usage: fax_image_dump input-image output.pgm [page-index]\n");
        return 2;
    }
    page = (argc > 3) ? strtoul(argv[3], (char **)0, 10) : 0UL;
    if (!fax_image_load_file(argv[1], page, &image, error_text,
                             (fax_index)sizeof(error_text))) {
        fprintf(stderr, "decode failed: %s\n", error_text);
        return 3;
    }
    output = fopen(argv[2], "wb");
    if (output == (FILE *)0) {
        fax_image_release(&image);
        return 4;
    }
    fprintf(output, "P5\n%lu %lu\n255\n", image.width, image.height);
    count = (size_t)(image.stride * image.height);
    if (fwrite(image.pixels, 1U, count, output) != count) {
        fclose(output);
        fax_image_release(&image);
        return 5;
    }
    fclose(output);
    printf("%s %lu %lu %.3f %.3f page=%lu\n", fax_image_format_name(image.format),
           image.width, image.height, image.dpi_x, image.dpi_y, image.selected_page);
    fax_image_release(&image);
    return 0;
}
