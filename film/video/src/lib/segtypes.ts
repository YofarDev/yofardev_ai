export type Seg = {
  /** composition-local frame the segment starts at */
  from: number;
  /** its length in frames */
  dur: number;
  tag: string;
  /** the run's clock at the segment's first frame */
  atMs: number;
  zoom?: number;
  focus?: [number, number];
  /** zoom at the segment's end (a slow push), default = zoom */
  zoomTo?: number;
  /** playback speed (the typing is sped up) */
  rate?: number;
};
