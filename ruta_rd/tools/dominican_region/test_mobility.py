import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mobility import allowed, directions, restriction
from temporal_filter import exclude


class Policy(unittest.TestCase):
    def test_motor_paths_and_overrides(self):
        self.assertFalse(allowed({'highway':'footway','access':'yes'},'motorcar'))
        self.assertFalse(allowed({'highway':'steps'},'motorcycle'))
        self.assertTrue(allowed({'highway':'residential','vehicle':'no','motorcar':'yes'},'motorcar'))
        self.assertFalse(allowed({'highway':'residential','motor_vehicle':'no'},'motorcycle'))
        self.assertFalse(allowed({'highway':'service','access':'private'},'motorcar'))
        self.assertFalse(allowed({'highway':'residential','access:conditional':'no @ (Mo-Fr)'},'motorcar'))

    def test_bike_and_barriers(self):
        self.assertTrue(allowed({'highway':'cycleway'},'bicycle'))
        self.assertFalse(allowed({'highway':'trunk'},'bicycle'))
        self.assertTrue(allowed({'highway':'trunk','bicycle':'yes'},'bicycle'))
        self.assertFalse(allowed({'highway':'path','bicycle':'dismount'},'bicycle'))
        self.assertFalse(allowed({'barrier':'bollard'},'motorcar',True))
        self.assertTrue(allowed({'barrier':'bollard'},'bicycle',True))

    def test_oneway_and_exceptions(self):
        self.assertEqual(directions({'oneway':'yes'},'motorcar'),(True,False))
        self.assertEqual(directions({'oneway':'-1'},'motorcycle'),(False,True))
        self.assertEqual(directions({'junction':'roundabout'},'motorcar'),(True,False))
        self.assertEqual(directions({'oneway':'yes','oneway:bicycle':'no'},'bicycle'),(True,True))
        self.assertEqual(restriction({'restriction':'no_left_turn','except':'bicycle'},'bicycle'),'')
        self.assertEqual(restriction({'restriction':'no_left_turn','except':'bicycle'},'motorcar'),'no_left_turn')
        self.assertEqual(restriction({'restriction:conditional':'no_left_turn @ (Mo-Fr)'},'motorcar'),'no_left_turn')

    def test_temporal_direction_and_motorroad(self):
        self.assertTrue(exclude({'oneway:conditional':'yes @ (07:00-09:00)'},'motorcar'))
        self.assertTrue(exclude({'oneway':'reversible'},'motorcycle'))
        self.assertTrue(exclude({'highway':'primary','motorroad':'yes'},'bicycle'))
        self.assertFalse(exclude({'motorroad':'yes','bicycle':'yes'},'bicycle'))


if __name__ == '__main__': unittest.main()
