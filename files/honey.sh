
#wget -o /dev/null -O - "http://activities.sugarlabs.org/services/micro-format.php?collection_nickname=miel&sugar=0.88"|grep olpc-activity-id |sed 's/.*>\(.*\)<\/.*/\1/'

# Honey subset
ASLO="$ASLO org.laptop.community.TypingTurtle"
ASLO="$ASLO org.sugarlabs.IRC"
ASLO="$ASLO com.garycmartin.Moon"
ASLO="$ASLO org.laptop.sugar.ReadEtextsActivity"
ASLO="$ASLO com.ywwg.CartoonBuilderActivity"
ASLO="$ASLO vu.lux.olpc.Speak"
ASLO="$ASLO org.laptop.ViewSlidesActivity"
ASLO="$ASLO org.sugarlabs.InfoSlicer"
ASLO="$ASLO org.worldwideworkshop.olpc.FlipSticks"
ASLO="$ASLO org.worldwideworkshop.olpc.JigsawPuzzle"
ASLO="$ASLO org.worldwideworkshop.olpc.SliderPuzzle"
ASLO="$ASLO org.laptop.community.Colors"
ASLO="$ASLO org.squeak.FreeCell"
ASLO="$ASLO org.laptop.Develop"
ASLO="$ASLO org.laptop.TamTamEdit"
ASLO="$ASLO org.laptop.TamTamJam"
ASLO="$ASLO org.laptop.TamTamMini"
ASLO="$ASLO org.laptop.TamTamSynthLab"
ASLO="$ASLO org.laptop.Memorize"
ASLO="$ASLO org.worldwideworkshop.JokeMachineActivity"
#ASLO="$ASLO vu.lux.olpc.Maze"
ASLO="$ASLO org.worldwideworkshop.olpc.storybuilder"
ASLO="$ASLO org.worldwideworkshop.PollBuilder"
ASLO="$ASLO org.gnome.Labyrinth"
ASLO="$ASLO org.laptop.RecordActivity"
ASLO="$ASLO org.laptop.Oficina"
#ASLO="$ASLO org.tuxpaint.sugar-is-lame"
ASLO="$ASLO tv.alterna.Clock"
ASLO="$ASLO org.laptop.physics"
#ASLO="$ASLO org.laptop.sugar.GetIABooksActivity"
ASLO="$ASLO org.laptop.Arithmetic"

WD=$PWD
BUNDLES_DIR=$PWD/honey
rm -rf $BUNDLES_DIR

mkdir -p $BUNDLES_DIR
cd $BUNDLES_DIR

CACHE_DIR=/tmp/aslo
mkdir -p $CACHE_DIR

ASLO_SP='0.86'
ASLO_URL='http://activities.sugarlabs.org/services/update-aslo.php'
ASLO_LINK='.//{http://www.mozilla.org/2004/em-rdf#}updateLink'

for bundle_id in $ASLO ; do
  curl -4 -s -L "$ASLO_URL?id=$bundle_id&appVersion=$ASLO_SP" > $CACHE_DIR/metadata
  url=$(python -c "from xml.etree.ElementTree import parse; url=parse('$CACHE_DIR/metadata').find('$ASLO_LINK'); print url is not None and url.text or ''")
  if [ -z "$url" ]; then
      echo "Can not find url for $bundle_id" >&2
      continue
  fi
  remote_file=$(basename $(curl -4 -s -L -w %{url_effective} -I $url | tail -1))
  bundle=$CACHE_DIR/$remote_file
  if [ ! -f $bundle ] ; then
     curl -4 -L $url > $bundle
  fi
  cp -p $bundle $BUNDLES_DIR
done

cd $BUNDLES_DIR
find *.xo -exec unzip '{}' \;
