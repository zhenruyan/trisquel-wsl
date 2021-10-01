# Trisquel Template

## Before Inkscape
### TRISQUELVERSION
In order to create the next release artwork the suggestion is to use sed to
adjust the TRISQUELVERSION with the current release 9.0, 10.0, etc.

Something like
`sed -i "s|TRISQUELVERSION|10.0|" ~/path-to/makeiso/files/artwork/gfxboot-template.svg`

### release-place-holder.png
Replace the release placeholder image  with the current release main image, also replace the path on the gfxboot-template.svg file, so it meets you ABSOLUTE path in the template svg:

```
sodipodi:absref="/FIX-PATH/makeiso/files/artwork/release-place-holder.png"
```

## With Inkscape
### Release images
The template inlcudes all the required icons, using inkscape you can alternate and
export the necessary images,

* back.jpg
* back-fsf.jpg
* grub.png
* grub-fsf.png

Make sure the resolution match 640x480 BEFORE exporting the images to png.

Please add or fix instructions on this README as needed.
